# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-09-03

### Added

- Initial release of Ueberauth DocuSign strategy
- OAuth2 Authorization Code Flow implementation
- Support for DocuSign demo and production environments
- User info extraction (email, name, accounts)
- CSRF protection via state parameter
- Comprehensive test suite with Bypass mocking
- Integration test framework for real API testing
- Support for custom OAuth scopes
- Automatic environment detection
- Complete documentation and examples

### Features

- Full OAuth2 compliance with DocuSign's implementation
- Support for multiple DocuSign accounts per user
- Token refresh capability
- Configurable redirect URIs
- Login hint support for pre-filling email
- Prompt parameter support for forcing re-authentication

### Security

- Client credentials properly secured
- State parameter for CSRF protection
- Secure token handling
- Support for production security best practices

[Unreleased]: https://github.com/neilberkman/ueberauth_docusign/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/neilberkman/ueberauth_docusign/releases/tag/v0.1.0
