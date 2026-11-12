<!--
SPDX-License-Identifier: AGPL-3.0-or-later
Zenflows is software that implements the Valueflows vocabulary.
Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

# Zenflows - Valueflows REA GraphDB

![Zenflows logo](https://github.com/dyne/zenflows/raw/master/docs/zenflows_rea_logo.png)

Zenflows is a tool to leverage commons-based peer production by
documenting and monitoring the life cycle of products. The goal is
that of enabling a federated network of organizations to bundle,
systematize and share data, information and knowledge about physical
artifacts.

[![software by Dyne.org](https://files.dyne.org/software_by_dyne.png)](http://www.dyne.org)

## Features

- Most validations are provable (and sealed by means of cryptography) using [Zenroom](https://zenroom.org) as core crypto component, including support for advanced Digital Product Passport schemes like
[REFLOW Portable Crypto Functions](https://medium.com/think-do-tank/reflow-crypto-material-passports-for-the-circular-economy-d75b3aa63678).

- The [Valueflows](https://valueflo.ws) vocabulary is adopted to govern a [Resource Event Agent](https://en.wikipedia.org/wiki/Resources,_Events,_Agents) accounting model and facilitate the development and execution of business logics built on top of it.

- The [PosgreSQL](https://postgresql.org) database backend is used as battle-tested data-storage solution well compatible with established enterprise standards in system administration, on top of it a GraphQL interface is developed based on the well performant [Elixir](https://elixir-lang.org) language framework.

Zenflows is a software component of the [INTERFACER project](https://www.interfacerproject.eu).


<h4 align="center">
  <a href="#-quick-start">🎮 Quick start</a>
  <span> • </span>
  <a href="#-install">💾 Install</a>
  <span> • </span>
  <a href="#-configuration">🔧 Configuration</a>
  <span> • </span>
  <a href="#-testing">📋 Testing</a>
  <span> • </span>
  <a href="#-styleguide">📘 Styleguide</a>
  <span> • </span>
  <a href="#-troubleshooting--debugging">🐛 Troubleshooting & debugging</a>
  <span> • </span>
  <a href="#-acknowledgements">😍 Acknowledgements</a>
  <span> • </span>
  <a href="#-links">🌐 Links</a>
  <span> • </span>
  <a href="#-contributing">👤 Contributing</a>
  <span> • </span>
  <a href="#-license">💼 License</a>
</h4>




<details id="toc">
 <summary><strong>🚩 Table of Contents</strong> (click to expand)</summary>

* [Quick start](#-quick-start)
* [Install](#-install)
* [Configuration](#-configuration)
* [Testing](#-testing)
* [Styleguide](#-styleguide)
* [Troubleshooting & debugging](#-troubleshooting--debugging)
* [Acknowledgements](#-acknowledgements)
* [Links](#-links)
* [Contributing](#-contributing)
* [License](#-license)
</details>

## 🎮 Quick start

To start using Zenflows with native-to-host Elixir, PostgreSQL, and Restroom instances:

1. Run `./mann env.setup` to generate the configuration file, `conf/env.sh`.
2. Edit `conf/env.sh` to suit your needs.  Read the [Configuration Guide](docs/configuration-guide.md) for more info.
3. Run `./mann dep.setup` to install dependencies.
5. Run `./mann serve` to start the application.
6. Head over to [`localhost:4000/play`](http://localhost:4000/play) for the GraphiQL playground.
7. Use the URL `http://localhost:4000/api` in case if you'd like to use your own GraphQL client.

To start using Zenflows with docker(-compose):

1. Run `./mann devop.serve` to generate the docker-compose file (automatically filled) and start the application.

If you want to edit the generated docker-copmose file:

1. Run `./mann devop.setup` to generate the docker-copmose file, `devop/docker-compose.yml`.
2. Edit `devop/docker-compose.yml` to suit your needs.  Read the [Configuration Guide](docs/configuration-guide.md) for more info.
3. Run `./mann devop.serve` to start the application.

**[🔝 back to top](#toc)**

***
## 💾 Install

🚧 TODO

**[🔝 back to top](#toc)**

***
## 🔧 Configuration

🚧 TODO

**[🔝 back to top](#toc)**

***

## 📋 Testing

🚧 TODO

**[🔝 back to top](#toc)**

***
## 📘 Styleguide

* Use tabs for indentation, spaces for aligment.
* Don't indent the top-level code in modules.
* Use trailing commas in multi-line lists, maps, functions, etc. where
  possible.

**[🔝 back to top](#toc)**

***
## 🐛 Troubleshooting & debugging

🚧 TODO

**[🔝 back to top](#toc)**

***
## 😍 Acknowledgements

[![software by Dyne.org](https://files.dyne.org/software_by_dyne.png)](http://www.dyne.org)

Copyleft (ɔ) 2021-2023 by [Dyne.org](https://www.dyne.org) foundation, Amsterdam

Designed, written and maintained by [srfsh](https://github.com/srfsh) with the help of [jaromil](https://github.com/jaromil), [puria](https://github.com/puria).

Reviews and suggestions contributed by [Lynn](https://github.com/fosterlynn), [Bob](https://github.com/bhaugen), and members of the Valueflows community.

### Funding

#### October 2021 – March 2023

This project was funded by the European Regional Development Fund (ERDF) as part of the INTERFACER project.

<img src="docs/assets/funding/logo_erdf2014.png" alt="EU ERDF Programme Logo" width="480">

#### January 2025 – December 2026

The further development of this project was supported as part of the "Fab City – Decentralized Digital Production for Urban Value Creation" project, funded by dtec.bw and supported by the European Union – NextGenerationEU.

<p>
  <img src="docs/assets/funding/dtec.bw_Logo_RGB_komplett.jpg" alt="dtec.bw logo" width="240">
  <img src="docs/assets/funding/nextgeneu_en.jpg" alt="Supported by the European Union – NextGenerationEU" width="360">
</p>

**[🔝 back to top](#toc)**

***
## 🌐 Links

https://interfacerproject.eu

https://dyne.org/

https://reflowproject.eu

https://www.valueflo.ws/

**[🔝 back to top](#toc)**

***
## 👤 Contributing

Please first take a look at the
[Dyne.org - Contributor License Agreement](CONTRIBUTING.md) then

1.  🔀 [FORK IT](../../fork)
2.  Create your feature branch `git checkout -b feat/branch`
3.  Commit your changes `git commit -am 'Add some fooBar'`
4.  Push to the branch `git push origin feature/branch`
5.  Create a new Pull Request `gh pr create -f`
6.  🙏 Thank you


**[🔝 back to top](#toc)**

***
## 💼 License
    Zenflows - Valueflows vocabulary
    Copyright (c) 2021-2023 Dyne.org foundation, Amsterdam

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


**[🔝 back to top](#toc)**
