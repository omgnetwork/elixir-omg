# Designing API specifications

OpenAPI definitions, allow devs to specify the operations and metadata of their APIs in machine-readable form. This enables them to automate various processes around the API lifecycle.

### Development specs

In order to facilitate the development and maintenance of the API documentation, the open api spec is splat into multiple files.

These files are grouped under a resource and each resource has 5 spec files. The basic structure is as follow:
```
/info_api_specs
  /resource1 (account for example)
    paths.yaml
    request_bodies.yaml
    response_schemas.yaml
    responses.yaml
    schemas.yaml
  /resource2
    paths.yaml
    request_bodies.yaml
    ...
  ...
```

Each of these file contain different part of the API definition.

When developing you should modify these files, under the `info_api_specs/` and `security_critical_api_specs/` folders and NOT directly the `info_api_specs.yaml` or `security_critical_api_specs.yaml` which are automatically generated.

### Generating the final spec file

When you are done editing the different spec files, you need to generate the final file which group all specifications together into one `"big"` file.

In order to do this you need to have the following installed and available:
  - [node.js](https://nodejs.org/en/download/package-manager/)
  - [swagger-cli](https://www.npmjs.com/package/swagger-cli). Install using: `npm install -g swagger-cli`
  - [openapi-generator](https://github.com/OpenAPITools/openapi-generator). Install using: `https://github.com/OpenAPITools/openapi-generator`

Then you need to run the following commands to generate the final spec.

**Watcher Security-Critical API:**

```
swagger-cli bundle -r -t yaml -o apps/omg_watcher_rpc/priv/swagger/security_critical_api_specs.yaml apps/omg_watcher_rpc/priv/swagger/security_critical_api_specs/swagger.yaml
openapi-generator-cli validate -i apps/omg_watcher_rpc/priv/swagger/security_critical_api_specs.yaml
```

**Watcher Info API:**

```
swagger-cli bundle -r -t yaml -o apps/omg_watcher_rpc/priv/swagger/info_api_specs.yaml apps/omg_watcher_rpc/priv/swagger/info_api_specs/swagger.yaml
openapi-generator-cli validate -i apps/omg_watcher_rpc/priv/swagger/info_api_specs.yaml
```
