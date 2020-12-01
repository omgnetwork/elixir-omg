---
title: OMG Network APIs Reference

language_tabs: # must be one of https://git.io/vQNgJ
  - shell
  - elixir
  - javascript

toc_footers:
  - <a href='https://github.com/lord/slate'>Documentation Powered by Slate</a>

includes:
  - operator_api_specs
  - watcher_api_specs
  - info_api_specs
  - errors

search: true
---

# Introduction

This is the HTTP-RPC API for the Child Chain Server and Watcher.

All calls use HTTP POST and pass options in the request body in JSON format.
Errors will usually return with HTTP response code 200, and the details of the error in the response body.
See [Errors](#errors).
