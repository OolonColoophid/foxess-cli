# FoxESS Swift CLI - Guidelines

## Build Commands
- Direct compile: `swiftc -o foxESS foxESS.swift`
- Build: `swift build`
- Run: `swift run foxESS [API_KEY] [options]`
- Run compiled binary: `./foxESS [API_KEY] [options]`
- Test: `swift test`
- Debug mode: `swift run foxESS [API_KEY] --debug`
- Test API key only: `swift run foxESS [API_KEY] --test`

## Code Style Guidelines
- **Naming**: Use camelCase for variables/properties, PascalCase for types
- **Formatting**: 4-space indentation, consistent spacing in expressions
- **Types**: Use strong typing, avoid force unwrapping, prefer optionals
- **Error Handling**: Use do-try-catch blocks for error handling
- **Organization**: Group code by models, extensions, API classes
- **Documentation**: Add comments for functions and complex sections
- **Constants**: Extract hardcoded values to constants or configurations
- **API Pattern**: Follow the async/await pattern for asynchronous code
- **Extensions**: Use extensions for adding functionality to existing types
- **Security**: Never log sensitive data like API keys or tokens