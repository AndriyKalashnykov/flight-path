# flight-path
REST API server to determine the flight path of a person

Story: There are over 100,000 flights a day, with millions of people and cargo being transferred around the world. 
With so many people and different carrier/agency groups, it can be hard to track where a person might be. 
In order to determine the flight path of a person, we must sort through all of their flight records.

Goal: To create a simple microservice API that can help us understand and track how a particular person's flight path 
may be queried. The API should accept a request that includes a list of flights, which are defined by a source and 
destination airport code. These flights may not be listed in order and will need to be sorted to find the total 
flight paths starting and ending airports.

### Requirements

- [gvm](https://github.com/moovweb/gvm) Go 1.19
    ```bash
    gvm install go1.19 --prefer-binary --with-build-tools --with-protobuf
    gvm use go1.19 --default
    ```
  
## Help

```text
Usage: make COMMAND
Commands :
help            - List available tasks
clean           - Cleanup
deps            - Download and install dependencies
api-docs        - Build source code for swagger api reference
test            - Run tests
build           - Build REST API server's binary
run             - Run REST API locally
release         - Create and push a new tag
update          - Update dependencies to latest versions
open-swagger    - Open browser with Swagger docs pointing to localhost
test-case-one   - Test case 1 [["SFO", "EWR"]]
test-case-two   - Test case 2 [["ATL", "EWR"], ["SFO", "ATL"]]
test-case-three - Test case 3 [["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]
```

## SwaggerUI

[Swagger API documentation - http://localhost:8080/swagger/index.html](http://localhost:8080/swagger/index.html)

![Swagger API documentation](./img/swagger-api-doc.jpg)
