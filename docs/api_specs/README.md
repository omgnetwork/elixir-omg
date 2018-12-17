# Working with API Docs

This repo contains `gh-pages` branch intended to host [Slate-based](#todo) API specification. Branch `gh-pages` is totally diseparated from other development branches and contains just Slate generated page's files.

## Updating API Specification
In `docs/api_specs/includes` folder there are numbered markdown files which forms final spec. Whenever API has changed and specs needs to be updated it should be updated along with the feature and pushed to the development branch. 

## To generate the API documentation

Checkout the gh-pages branch
```
git checkout gh-pages
```

Get the latest documentation files from `master`
```
git checkout master docs/api_specs
```

N.B You must have **Ruby, version 2.3.1 or newer** and **Bundler** (`gem install bundler`).

Generate the API documentation html files
```
cd docs/api_specs/
bundle install
bundle exec middleman build --clean --source=.
```

You can review the generated documentation locally by running `bundle exec middleman server --source=.` and opening `http://localhost:4567/`

## Publish the new API documentation

If everything worked, push the new changes
```
cp -r build/* ../..
git add --all
git commit -m "API docs: regenerate from <this repo current git-sha>"
git push
```

Now the updated docs are available at https://omisego.github.io/elixir-omg
