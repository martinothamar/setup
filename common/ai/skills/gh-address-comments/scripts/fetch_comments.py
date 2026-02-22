#!/usr/bin/env python3
"""
Fetch all PR conversation comments + reviews + review threads (inline threads)
for the PR associated with the current git branch, by shelling out to:

  gh api graphql

Requires:
  - valid `gh` auth already configured
  - current branch has an associated (open) PR

Usage:
  python fetch_comments.py                             # full markdown summary
  python fetch_comments.py --actionable                # unresolved + non-outdated threads only
  python fetch_comments.py --actionable --outdated     # unresolved threads incl. outdated
  python fetch_comments.py --thread THREAD_ID          # full details for one thread
  python fetch_comments.py --json --actionable         # minimal actionable JSON
  python fetch_comments.py --resolve ID [ID ...]       # resolve by thread ID
  python fetch_comments.py --resolve-indexes 1 3       # resolve by actionable indexes

When output is large, the script writes full output to `/tmp/fetch_comments_*.md|json`
and prints the path to read from.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from typing import Any

QUERY = """\
query(
  $owner: String!,
  $repo: String!,
  $number: Int!,
  $commentsCursor: String,
  $reviewsCursor: String,
  $threadsCursor: String
) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      number
      url
      title
      state

      # Top-level "Conversation" comments (issue comments on the PR)
      comments(first: 100, after: $commentsCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          body
          createdAt
          updatedAt
          author { login }
        }
      }

      # Review submissions (Approve / Request changes / Comment), with body if present
      reviews(first: 100, after: $reviewsCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          state
          body
          submittedAt
          author { login }
        }
      }

      # Inline review threads (grouped), includes resolved state
      reviewThreads(first: 100, after: $threadsCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          diffSide
          startLine
          startDiffSide
          originalLine
          originalStartLine
          resolvedBy { login }
          comments(first: 100) {
            nodes {
              id
              body
              createdAt
              updatedAt
              author { login }
            }
          }
        }
      }
    }
  }
}
"""

RESOLVE_MUTATION = """\
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread {
      id
      isResolved
    }
  }
}
"""

MAX_INLINE_OUTPUT_CHARS = 12000
MAX_INLINE_OUTPUT_LINES = 220


def _run(cmd: list[str], stdin: str | None = None) -> str:
    p = subprocess.run(cmd, input=stdin, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{p.stderr}")
    return p.stdout


def _run_json(cmd: list[str], stdin: str | None = None) -> dict[str, Any]:
    out = _run(cmd, stdin=stdin)
    try:
        return json.loads(out)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Failed to parse JSON from command output: {e}\nRaw:\n{out}") from e


def _write_large_output(content: str, *, suffix: str) -> str:
    fd, path = tempfile.mkstemp(prefix="fetch_comments_", suffix=suffix, dir="/tmp", text=True)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(content)
        if content and not content.endswith("\n"):
            fh.write("\n")
    return path


def _emit_output(content: str, *, json_output: bool) -> None:
    line_count = content.count("\n") + (1 if content else 0)
    if len(content) <= MAX_INLINE_OUTPUT_CHARS and line_count <= MAX_INLINE_OUTPUT_LINES:
        print(content)
        return

    suffix = ".json" if json_output else ".md"
    path = _write_large_output(content, suffix=suffix)
    print(f"Output is large ({len(content)} chars, {line_count} lines). Wrote it to `{path}`.")
    print(f"Read the full output from `{path}`.")


def _ensure_gh_authenticated() -> None:
    try:
        _run(["gh", "auth", "status"])
    except RuntimeError:
        print("run `gh auth login` to authenticate the GitHub CLI", file=sys.stderr)
        raise RuntimeError("gh auth status failed; run `gh auth login` to authenticate the GitHub CLI") from None


def gh_pr_view_json(fields: str) -> dict[str, Any]:
    # fields is a comma-separated list like: "number,headRepositoryOwner,headRepository"
    return _run_json(["gh", "pr", "view", "--json", fields])


def get_current_pr_ref() -> tuple[str, str, int]:
    """
    Resolve the PR for the current branch (whatever gh considers associated).
    Works for cross-repo PRs too, by reading head repository owner/name.
    """
    pr = gh_pr_view_json("number,headRepositoryOwner,headRepository")
    owner = pr["headRepositoryOwner"]["login"]
    repo = pr["headRepository"]["name"]
    number = int(pr["number"])
    return owner, repo, number


def gh_api_graphql(
    owner: str,
    repo: str,
    number: int,
    comments_cursor: str | None = None,
    reviews_cursor: str | None = None,
    threads_cursor: str | None = None,
) -> dict[str, Any]:
    """
    Call `gh api graphql` using -F variables, avoiding JSON blobs with nulls.
    Query is passed via stdin using query=@- to avoid shell newline/quoting issues.
    """
    cmd = [
        "gh",
        "api",
        "graphql",
        "-F",
        "query=@-",
        "-F",
        f"owner={owner}",
        "-F",
        f"repo={repo}",
        "-F",
        f"number={number}",
    ]
    if comments_cursor:
        cmd += ["-F", f"commentsCursor={comments_cursor}"]
    if reviews_cursor:
        cmd += ["-F", f"reviewsCursor={reviews_cursor}"]
    if threads_cursor:
        cmd += ["-F", f"threadsCursor={threads_cursor}"]

    return _run_json(cmd, stdin=QUERY)


def fetch_all(owner: str, repo: str, number: int) -> dict[str, Any]:
    conversation_comments: list[dict[str, Any]] = []
    reviews: list[dict[str, Any]] = []
    review_threads: list[dict[str, Any]] = []

    comments_cursor: str | None = None
    reviews_cursor: str | None = None
    threads_cursor: str | None = None

    pr_meta: dict[str, Any] | None = None

    while True:
        payload = gh_api_graphql(
            owner=owner,
            repo=repo,
            number=number,
            comments_cursor=comments_cursor,
            reviews_cursor=reviews_cursor,
            threads_cursor=threads_cursor,
        )

        if "errors" in payload and payload["errors"]:
            raise RuntimeError(f"GitHub GraphQL errors:\n{json.dumps(payload['errors'], indent=2)}")

        pr = payload["data"]["repository"]["pullRequest"]
        if pr_meta is None:
            pr_meta = {
                "number": pr["number"],
                "url": pr["url"],
                "title": pr["title"],
                "state": pr["state"],
                "owner": owner,
                "repo": repo,
            }

        c = pr["comments"]
        r = pr["reviews"]
        t = pr["reviewThreads"]

        conversation_comments.extend(c.get("nodes") or [])
        reviews.extend(r.get("nodes") or [])
        review_threads.extend(t.get("nodes") or [])

        comments_cursor = c["pageInfo"]["endCursor"] if c["pageInfo"]["hasNextPage"] else None
        reviews_cursor = r["pageInfo"]["endCursor"] if r["pageInfo"]["hasNextPage"] else None
        threads_cursor = t["pageInfo"]["endCursor"] if t["pageInfo"]["hasNextPage"] else None

        if not (comments_cursor or reviews_cursor or threads_cursor):
            break

    assert pr_meta is not None
    return {
        "pull_request": pr_meta,
        "conversation_comments": conversation_comments,
        "reviews": reviews,
        "review_threads": review_threads,
    }


def resolve_thread(thread_id: str) -> dict[str, Any]:
    cmd = [
        "gh",
        "api",
        "graphql",
        "-F",
        "query=@-",
        "-F",
        f"threadId={thread_id}",
    ]
    payload = _run_json(cmd, stdin=RESOLVE_MUTATION)
    if "errors" in payload and payload["errors"]:
        raise RuntimeError(f"GraphQL errors resolving thread {thread_id}:\n{json.dumps(payload['errors'], indent=2)}")
    return payload["data"]["resolveReviewThread"]["thread"]


def _author_login(node: dict[str, Any]) -> str:
    author = node.get("author")
    if isinstance(author, dict):
        login = author.get("login")
        if isinstance(login, str) and login:
            return login
    return "unknown"


def _collapse_whitespace(value: str) -> str:
    return " ".join(value.split())


def _strip_autogenerated_sections(value: str) -> str:
    # Keep lead content but drop bulky bot sections that mostly add token cost.
    no_html_comments = re.sub(r"<!--.*?-->", " ", value, flags=re.DOTALL)
    no_details = re.sub(r"<details>.*?</details>", " ", no_html_comments, flags=re.DOTALL | re.IGNORECASE)
    return no_details


def _truncate_text(value: str, *, max_chars: int | None) -> str:
    if max_chars is None or len(value) <= max_chars:
        return value
    if max_chars <= 3:
        return value[:max_chars]
    return f"{value[: max_chars - 3]}..."


def _normalize_body(raw: str, *, strip_auto_sections: bool, max_chars: int | None) -> str:
    source = _strip_autogenerated_sections(raw) if strip_auto_sections else raw
    normalized = _collapse_whitespace(source)
    if not normalized:
        normalized = _collapse_whitespace(raw)
    return _truncate_text(normalized, max_chars=max_chars)


def _thread_location(thread: dict[str, Any]) -> str:
    path = thread.get("path") or "<unknown-path>"
    line = thread.get("line")
    if isinstance(line, int):
        return f"{path}:{line}"
    return path


def _latest_thread_comment(thread: dict[str, Any]) -> dict[str, Any]:
    comments = (thread.get("comments") or {}).get("nodes") or []
    return comments[-1] if comments else {}


def _extract_severity(text: str) -> str:
    match = re.search(r"(?<![A-Za-z])(critical|major|minor|nitpick)(?![A-Za-z])", text, flags=re.IGNORECASE)
    if not match:
        return "unknown"
    return match.group(1).lower()


def _normalize_bot_filters(values: list[str] | None) -> set[str]:
    if not values:
        return set()
    result: set[str] = set()
    for value in values:
        for token in value.split(","):
            item = token.strip().lower()
            if item:
                result.add(item)
    return result


def build_actionable_rows(
    review_threads: list[dict[str, Any]],
    *,
    bot_filters: set[str],
    include_outdated: bool,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for thread in review_threads:
        if thread.get("isResolved"):
            continue
        if thread.get("isOutdated") and not include_outdated:
            continue

        latest = _latest_thread_comment(thread)
        author = _author_login(latest)
        if bot_filters and author.lower() in bot_filters:
            continue

        rows.append(
            {
                "index": len(rows) + 1,
                "thread_id": thread["id"],
                "path": thread.get("path") or "<unknown-path>",
                "line": thread.get("line") if isinstance(thread.get("line"), int) else None,
                "is_outdated": bool(thread.get("isOutdated")),
                "author": author,
                "raw_body": latest.get("body") or "",
                "severity": _extract_severity(latest.get("body") or ""),
                "thread": thread,
            }
        )
    return rows


def _actionable_json_rows(
    actionable_rows: list[dict[str, Any]],
    *,
    max_body_chars: int | None,
    strip_auto_sections: bool,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for row in actionable_rows:
        rows.append(
            {
                "index": row["index"],
                "thread_id": row["thread_id"],
                "path": row["path"],
                "line": row["line"],
                "author": row["author"],
                "body": _normalize_body(
                    row["raw_body"],
                    strip_auto_sections=strip_auto_sections,
                    max_chars=max_body_chars,
                ),
                "severity": row["severity"],
            }
        )
    return rows


def format_actionable_markdown(
    pr: dict[str, Any],
    actionable_rows: list[dict[str, Any]],
    *,
    max_body_chars: int | None,
    strip_auto_sections: bool,
    bot_filters: set[str],
) -> str:
    lines = [
        f'# PR #{pr["number"]}: {pr["title"]}',
        "",
        f'- URL: {pr["url"]}',
        f"- Actionable threads: {len(actionable_rows)}",
    ]
    if bot_filters:
        lines.append(f"- Bot filter: {', '.join(sorted(bot_filters))}")
    if any(row["is_outdated"] for row in actionable_rows):
        lines.append("- Includes outdated threads: yes")
    lines.extend(["", "## Actionable Review Threads"])

    if not actionable_rows:
        lines.append("- None")
        return "\n".join(lines)

    for row in actionable_rows:
        location = row["path"] if row["line"] is None else f'{row["path"]}:{row["line"]}'
        body = _normalize_body(
            row["raw_body"],
            strip_auto_sections=strip_auto_sections,
            max_chars=max_body_chars,
        )
        lines.append(
            f'{row["index"]}. `[{row["thread_id"]}]` `{location}` - @{row["author"]} '
            f'[{row["severity"]}]{" [outdated]" if row["is_outdated"] else ""}: "{body}"'
        )
    return "\n".join(lines)


def format_thread_markdown(pr: dict[str, Any], thread: dict[str, Any]) -> str:
    comments = (thread.get("comments") or {}).get("nodes") or []
    lines = [
        f'# PR #{pr["number"]}: {pr["title"]}',
        "",
        "## Thread",
        f'- ID: {thread["id"]}',
        f'- Location: {_thread_location(thread)}',
        f'- Resolved: {bool(thread.get("isResolved"))}',
        f'- Outdated: {bool(thread.get("isOutdated"))}',
        "",
        "## Comments",
    ]

    if not comments:
        lines.append("- None")
        return "\n".join(lines)

    for idx, comment in enumerate(comments, start=1):
        body = comment.get("body") or ""
        lines.extend(
            [
                f"{idx}. @{_author_login(comment)}",
                f"   - ID: {comment.get('id', '<unknown-id>')}",
                f"   - Created: {comment.get('createdAt', '<unknown-time>')}",
                "   - Body:",
                "```text",
                body,
                "```",
            ]
        )
    return "\n".join(lines)


def format_human_summary(
    payload: dict[str, Any],
    *,
    max_body_chars: int | None,
    strip_auto_sections: bool,
    bot_filters: set[str],
    include_outdated: bool,
) -> str:
    pr = payload["pull_request"]
    review_threads = payload.get("review_threads") or []
    conversation_comments = payload.get("conversation_comments") or []
    reviews = payload.get("reviews") or []

    pending_threads = []
    for thread in review_threads:
        if thread.get("isResolved"):
            continue
        if thread.get("isOutdated") and not include_outdated:
            continue
        latest = _latest_thread_comment(thread)
        if bot_filters and _author_login(latest).lower() in bot_filters:
            continue
        pending_threads.append(thread)

    resolved_count = sum(1 for thread in review_threads if thread.get("isResolved"))
    outdated_count = sum(1 for thread in review_threads if thread.get("isOutdated"))

    lines = [
        f'# PR #{pr["number"]}: {pr["title"]}',
        "",
        f'- URL: {pr["url"]}',
        f"- Open threads to address: {len(pending_threads)}",
    ]
    if include_outdated:
        if resolved_count:
            lines.append(f"- Excluded threads (resolved): {resolved_count}")
        if outdated_count:
            lines.append(f"- Included outdated threads: {outdated_count}")
    else:
        excluded_threads = len(review_threads) - len(pending_threads)
        if excluded_threads:
            lines.append(f"- Excluded threads (resolved/outdated): {excluded_threads}")
    if bot_filters:
        lines.append(f"- Bot filter: {', '.join(sorted(bot_filters))}")
    lines.extend(["", "## Review Threads"])

    if not pending_threads:
        lines.append("- None")
    else:
        for idx, thread in enumerate(pending_threads, start=1):
            latest = _latest_thread_comment(thread)
            snippet = _normalize_body(
                latest.get("body") or "",
                strip_auto_sections=strip_auto_sections,
                max_chars=max_body_chars,
            )
            outdated_tag = " [outdated]" if thread.get("isOutdated") else ""
            lines.append(
                f'{idx}. `[{thread["id"]}]` `{_thread_location(thread)}`{outdated_tag} - '
                f'@{_author_login(latest)}: "{snippet}"'
            )

    lines.extend(["", "## Other Comments"])
    other_count = 0
    for comment in conversation_comments:
        if bot_filters and _author_login(comment).lower() in bot_filters:
            continue
        other_count += 1
        snippet = _normalize_body(
            comment.get("body") or "",
            strip_auto_sections=strip_auto_sections,
            max_chars=max_body_chars,
        )
        lines.append(f'{other_count}. conversation - @{_author_login(comment)}: "{snippet}"')

    for review in reviews:
        body = review.get("body") or ""
        if not body.strip():
            continue
        if bot_filters and _author_login(review).lower() in bot_filters:
            continue
        other_count += 1
        state = review.get("state") or "UNKNOWN"
        snippet = _normalize_body(
            body,
            strip_auto_sections=strip_auto_sections,
            max_chars=max_body_chars,
        )
        lines.append(f'{other_count}. review/{state} - @{_author_login(review)}: "{snippet}"')

    if other_count == 0:
        lines.append("- None")

    return "\n".join(lines)


def _find_thread(review_threads: list[dict[str, Any]], thread_id: str) -> dict[str, Any]:
    for thread in review_threads:
        if thread.get("id") == thread_id:
            return thread
    raise RuntimeError(f"thread not found: {thread_id}")


def _resolve_indexes_to_thread_ids(actionable_rows: list[dict[str, Any]], indexes: list[int]) -> list[str]:
    by_index: dict[int, str] = {row["index"]: row["thread_id"] for row in actionable_rows}
    result: list[str] = []
    seen: set[str] = set()
    for index in indexes:
        if index not in by_index:
            raise RuntimeError(f"invalid index {index}; valid range is 1..{len(actionable_rows)}")
        thread_id = by_index[index]
        if thread_id in seen:
            continue
        seen.add(thread_id)
        result.append(thread_id)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--actionable",
        action="store_true",
        help="show unresolved and non-outdated review threads only",
    )
    parser.add_argument(
        "--outdated",
        action="store_true",
        help="include unresolved outdated threads in actionable/summary output",
    )
    parser.add_argument(
        "--thread",
        metavar="THREAD_ID",
        help="show full details for one review thread",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="print JSON output instead of markdown",
    )
    parser.add_argument(
        "--max-body-chars",
        type=int,
        default=120,
        help="max chars per comment body in summary/actionable output (default: 120)",
    )
    parser.add_argument(
        "--no-truncate",
        action="store_true",
        help="disable body truncation in summary/actionable output",
    )
    parser.add_argument(
        "--bot-filter",
        action="append",
        default=[],
        metavar="LOGIN[,LOGIN...]",
        help="exclude comments/threads by author login (repeatable or comma-separated)",
    )
    parser.add_argument(
        "--resolve",
        metavar="THREAD_ID",
        nargs="+",
        help="resolve one or more review thread IDs via the GitHub GraphQL API",
    )
    parser.add_argument(
        "--resolve-indexes",
        metavar="INDEX",
        nargs="+",
        type=int,
        help="resolve one or more actionable thread indexes",
    )
    args = parser.parse_args()

    if args.max_body_chars < 1:
        parser.error("--max-body-chars must be >= 1")

    exclusive_mode_count = int(bool(args.resolve)) + int(bool(args.resolve_indexes)) + int(bool(args.thread))
    if exclusive_mode_count > 1:
        parser.error("choose at most one of --resolve, --resolve-indexes, or --thread")

    _ensure_gh_authenticated()

    max_body_chars = None if args.no_truncate else args.max_body_chars
    bot_filters = _normalize_bot_filters(args.bot_filter)
    strip_auto_sections = True

    if args.resolve:
        results = []
        status_lines: list[str] = []
        for thread_id in args.resolve:
            thread = resolve_thread(thread_id)
            results.append(thread)
            if not args.json:
                status_lines.append(f"Resolved thread {thread['id']}: isResolved={thread['isResolved']}")
        if args.json:
            _emit_output(json.dumps(results, indent=2), json_output=True)
        else:
            _emit_output("\n".join(status_lines), json_output=False)
        return

    owner, repo, number = get_current_pr_ref()
    result = fetch_all(owner, repo, number)
    review_threads = result.get("review_threads") or []

    if args.thread:
        thread = _find_thread(review_threads, args.thread)
        if args.json:
            _emit_output(json.dumps(thread, indent=2), json_output=True)
        else:
            _emit_output(format_thread_markdown(result["pull_request"], thread), json_output=False)
        return

    actionable_rows = build_actionable_rows(
        review_threads,
        bot_filters=bot_filters,
        include_outdated=args.outdated,
    )

    if args.resolve_indexes:
        thread_ids = _resolve_indexes_to_thread_ids(actionable_rows, args.resolve_indexes)
        results = []
        status_lines: list[str] = []
        for thread_id in thread_ids:
            thread = resolve_thread(thread_id)
            results.append(thread)
            if not args.json:
                status_lines.append(f"Resolved thread {thread['id']}: isResolved={thread['isResolved']}")
        if args.json:
            _emit_output(json.dumps(results, indent=2), json_output=True)
        else:
            _emit_output("\n".join(status_lines), json_output=False)
        return

    if args.json and args.actionable:
        _emit_output(
            json.dumps(
                _actionable_json_rows(
                    actionable_rows,
                    max_body_chars=max_body_chars,
                    strip_auto_sections=strip_auto_sections,
                ),
                indent=2,
            ),
            json_output=True,
        )
        return

    if args.json:
        _emit_output(json.dumps(result, indent=2), json_output=True)
        return

    if args.actionable:
        _emit_output(
            format_actionable_markdown(
                result["pull_request"],
                actionable_rows,
                max_body_chars=max_body_chars,
                strip_auto_sections=strip_auto_sections,
                bot_filters=bot_filters,
            ),
            json_output=False,
        )
        return

    _emit_output(
        format_human_summary(
            result,
            max_body_chars=max_body_chars,
            strip_auto_sections=strip_auto_sections,
            bot_filters=bot_filters,
            include_outdated=args.outdated,
        ),
        json_output=False,
    )


if __name__ == "__main__":
    main()
