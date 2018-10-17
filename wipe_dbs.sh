rm -rf ~/.omg/*
mix run --no-start -e 'OMG.DB.init()'
echo "OMG API DB ready"

cd apps/omg_watcher
mix do ecto.reset --no-start, run --no-start -e 'OMG.DB.init()' --config ../../watcher_config.exs
echo "OMG Watcher DB ready"
