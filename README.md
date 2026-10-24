# Extension Control

Free base component of the **54PowerTools** suite for SAP S/4HANA, by [54P Solutions GmbH](https://54p.eu).

ABAP namespace: `/S4P0/`

> Source-available under the [PolyForm Shield License 1.0.0](LICENSE.md).
> Free to use, including productive use in your company and in customer projects.
> This is not open source in the OSI sense - please read [License](#license).

## What it does

Extension Control brings structure and transparency to customer-specific developments in SAP S/4HANA. Every extension is encapsulated in a consistent, documented framework, so it stays clearly separated from the standard and can be transported cleanly. Built-in usage tracking shows how often and in which context each extension is called, which gives you data instead of gut feeling.

Extensions can be activated for selected users only, so you can pilot them and roll them out step by step without branching the code. If an extension causes problems, you can switch it off through customizing, with no transport and no local code change. The footprint overview shows which extensions exist, which are active and which are actually used. In S/4HANA migrations, that usage data tells you what to migrate first and what to clean up, so unused code doesn't get migrated at all.

## Requirements

- SAP NetWeaver ;  developed and tested on  NW AS ABAP 7.52 SP15
- SAP S/4HANA ; tested on S/4HANA 2025 FPS01
- [abapGit](https://abapgit.org) (standalone report or developer version) => Tested with: 1.134.0 - Standalone Version 
- Authorization to create objects and repair tasks in the target system

## Installation

The software lives in the registered namespace `/S4P0/`. The namespace must exist in your system before the objects can be imported.

### 1. Set up the namespace

Option A, automatic: abapGit creates the namespace from the file `#s4p0#.nspc.xml` in this repository. Pull that object first, then pull the rest.

Option B, manual (transaction SE03):

1. *Display/Change Namespaces*: create `/S4P0/`, role **C (Recipient)**, repair license `06495637110217787197`.
2. *Set System Change Option*: set namespace `/S4P0/` to **modifiable**.

### 2. Import with abapGit

1. Start abapGit and choose **New Online**.
2. URL: `https://github.com/54P-Solutions/54p-extension-control.git`
3. Package: `/S4P0/MAIN` (create it when abapGit asks).
4. **Clone**, then **Pull**. abapGit asks for a transport request. Namespaced objects are recorded in repair tasks.
5. Activate all inactive objects.

### Update

Open the repository in abapGit and choose **Pull**. Releases are listed under [Releases](../../releases).

## License

Extension Control is licensed under the [PolyForm Shield License 1.0.0](LICENSE.md). Plain-language summary, not legal advice - the license text applies:

| Allowed | Not allowed |
|---|---|
| Use it for any purpose, including commercial and productive use | Sell, resell or license it, alone or bundled |
| Use it in customer projects as a consultant or partner | Provide a product that competes with it or with 54PowerTools |
| Change it for your own needs | Remove the copyright notice |
| Pass it on free of charge, with the license and notice | |

Copyright 54P Solutions GmbH. All rights not granted by the license remain with 54P Solutions GmbH.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first - every contribution requires signing the [Contributor License Agreement](CLA.md).

## Security

Please do not report vulnerabilities in public issues. See [SECURITY.md](SECURITY.md).

## 54PowerTools

Extension Control is the foundation of the commercial 54PowerTools suite: control, transparency and speed for SAP S/4HANA transformation, projects and operations. More at [54p.eu](https://54p.eu).
