# [ReportPortal.io](http://ReportPortal.io)

[![Join Slack chat!](https://slack.epmrpp.reportportal.io/badge.svg)](https://slack.epmrpp.reportportal.io/)
[![stackoverflow](https://img.shields.io/badge/reportportal-stackoverflow-orange.svg?style=flat)](http://stackoverflow.com/questions/tagged/reportportal)
[![GitHub contributors](https://img.shields.io/badge/contributors-102-blue.svg)](https://reportportal.io/community)
[![Docker Pulls](https://img.shields.io/docker/pulls/reportportal/service-api.svg?maxAge=25920)](https://hub.docker.com/u/reportportal/)
[![License](https://img.shields.io/badge/license-Apache-brightgreen.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Build with Love](https://img.shields.io/badge/build%20with-❤%EF%B8%8F%E2%80%8D-lightgrey.svg)](http://reportportal.io?style=flat)


ReportPortal is a TestOps service, that provides increased capabilities to speed up results analysis and reporting through the use of built-in analytic features.

ReportPortal is a great addition to Continuous Integration and Continuous Testing process.

ReportPortal is distributed under the Apache v2.0 license, and it is free to use and modify, even for commercial purposes. We offer the only paid premium feature – Quality Gates.

If a company is interested in our services, we can provide support hours to deploy, integrate, configure, or customize the tool, as well as SaaS options.

## Requirements
* Kubernetes v1.19-1.24
* Helm Package Manager v3.4+

## Usage notes and getting started
* [ReportPortal](https://github.com/reportportal/kubernetes/tree/master/reportportal)

## Documentation
* [User Manual](http://reportportal.io/#documentation)
* [Wiki and Guides](https://github.com/reportportal/reportportal/wiki)

## Community / Support
* [**Slack chat**](https://reportportal-slack-auto.herokuapp.com)
* [**Security Advisories**](https://github.com/reportportal/reportportal/blob/master/SECURITY_ADVISORIES.md)
* [GitHub Issues](https://github.com/reportportal/reportportal/issues)
* [Stackoverflow Questions](http://stackoverflow.com/questions/tagged/reportportal)
* [Twitter](http://twitter.com/ReportPortal_io)
* [Facebook](https://www.facebook.com/ReportPortal.io)
* [YouTube Channel](https://www.youtube.com/channel/UCsZxrHqLHPJcrkcgIGRG-cQ)

## License
Report Portal is [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).

## Installation

```bash
helm upgrade --install reportportal --set uat.superadminInitPasswd.password=erebus  ./kubernetes/ --wait
```