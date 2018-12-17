# Errors

Note that HTTP calls will almost always return `200`, even if the result is an error. One exception to this is if an internal server error occurs - in this case it will return `500`

When an error occurs, `success` will be set to `false` and `data` will contain more information about the error

```json
{
  "version": "1",
  "success": false,
  "data": {
    "code": "account:not_found",
    "description": "Account not found"
  }
}
```