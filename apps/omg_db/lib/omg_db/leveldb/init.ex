defmodule OMG.DB.LevelDB.Init do
  use GenServer

  def start_link([db_path: _db_path] = args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(db_path: db_path) do
    :ok = File.mkdir_p(db_path)
    {:ok, db_ref} = Exleveldb.open(db_path, create_if_missing: true)
    #Initializes an empty LevelDB instance explicitly, so we can have control over it.
    #NOTE: `init` here is to init the GenServer and that assumes that `init_storage` has already been called
    true = Exleveldb.is_empty?(db_ref)
    {:ok, db_ref}
  end

  def terminate(_, db_ref), do: Exleveldb.close(db_ref)

end
