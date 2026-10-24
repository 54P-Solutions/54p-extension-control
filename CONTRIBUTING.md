# Contributing to Extension Control

Thanks for helping. Please read this page before you open a pull request.

## How development works

Development of Extension Control happens in the internal repository of 54P Solutions GmbH. This GitHub repository is the published copy and receives every release.

What this means for you:

1. Pull requests are reviewed here on GitHub as usual.
2. Accepted pull requests are merged in the internal repository, not with the GitHub merge button.
3. With the next release your commits appear on GitHub, with you as author, and GitHub marks the pull request as merged.

So there can be a delay between "accepted" and "merged". We comment on the pull request when it is accepted.

## Before you start

- **Bug:** open an issue with the bug template. A pull request with a fix is welcome.
- **New feature or larger change:** open an issue or a discussion first, so we can agree on the approach before you spend time on it.

## Contributor License Agreement

Every contributor must sign the [Contributor License Agreement](CLA.md) once. The CLA Assistant bot asks you to do this in your first pull request; signing is one comment.

Why: Extension Control is the foundation of a commercial product. The CLA allows 54P Solutions GmbH to use your contribution in all its products and under all licenses. Your copyright stays with you.

## Rules for code

1. All objects in the namespace `/S4P0/`. No objects in other namespaces or the customer namespace (Z/Y).
2. No modifications of SAP standard objects; use released APIs where available.
3. Serialize with abapGit. Do not edit the XML files by hand.
4. Clean ABAP: meaningful names, small methods, no obsolete statements.
5. One topic per pull request. Keep unrelated formatting changes out.
6. Do not change the public API (`/S4P0/IF_*` interfaces) without discussing it in an issue first. Other products depend on it.
7. Describe in the pull request on which SAP release you tested.

## Commit messages

Short summary in the first line (max. 72 characters), imperative ("Fix ...", "Add ..."). Details after a blank line.

## Questions

Use [Discussions](../../discussions) for questions and ideas.
