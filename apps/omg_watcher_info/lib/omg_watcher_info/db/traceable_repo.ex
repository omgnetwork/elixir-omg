defmodule OMG.WatcherInfo.DB.TraceableRepo do
  alias OMG.WatcherInfo.DB.Repo
  alias OMG.WatcherInfo.Tracer

  def aggregate(queryable, aggregate, field, opts \\ []),
    do: trace(fn -> Repo.aggregate(queryable, aggregate, field, opts) end, opts)

  def all(queryable, opts \\ []), do: trace(fn -> Repo.aggregate(queryable, opts) end, opts)

  def delete(struct_or_changeset, opts \\ []), do: trace(fn -> Repo.delete(struct_or_changeset, opts) end, opts)

  def delete!(struct_or_changeset, opts \\ []), do: trace(fn -> Repo.delete!(struct_or_changeset, opts) end, opts)

  def delete_all(queryable, opts \\ []), do: trace(fn -> Repo.delete_all(queryable, opts) end, opts)

  def exists?(queryable, opts \\ []), do: trace(fn -> Repo.exists?(queryable, opts) end, opts)

  def get(queryable, id, opts \\ []), do: trace(fn -> Repo.get(queryable, id, opts) end, opts)

  def get!(queryable, id, opts \\ []), do: trace(fn -> Repo.get!(queryable, id, opts) end, opts)

  def get_by(queryable, clauses, opts \\ []), do: trace(fn -> Repo.get_by(queryable, clauses, opts) end, opts)

  def get_by!(queryable, clauses, opts \\ []), do: trace(fn -> Repo.get_by!(queryable, clauses, opts) end, opts)

  def insert(struct_or_changeset, opts \\ []), do: trace(fn -> Repo.insert(struct_or_changeset, opts) end, opts)

  def insert!(struct_or_changeset, opts \\ []), do: trace(fn -> Repo.insert!(struct_or_changeset, opts) end, opts)

  def insert_all(schema_or_source, entries, opts \\ []),
    do: trace(fn -> Repo.insert_all(schema_or_source, entries, opts) end, opts)

  def insert_or_update(changeset, opts \\ []), do: trace(fn -> Repo.insert_or_update(changeset, opts) end, opts)

  def insert_or_update!(changeset, opts \\ []), do: trace(fn -> Repo.insert_or_update!(changeset, opts) end, opts)

  def load(module_or_map, data, opts \\ []), do: trace(fn -> Repo.load(module_or_map, data) end, opts)

  def one(queryable, opts \\ []), do: trace(fn -> Repo.one(queryable, opts) end, opts)

  def one!(queryable, opts \\ []), do: trace(fn -> Repo.one!(queryable, opts) end, opts)

  def preload(structs_or_struct_or_nil, preloads, opts \\ []),
    do: trace(fn -> Repo.preload(structs_or_struct_or_nil, preloads, opts) end, opts)

  def rollback(value, opts \\ []), do: trace(fn -> Repo.rollback(value) end, opts)

  def stream(queryable, opts \\ []), do: trace(fn -> Repo.stream(queryable, opts) end, opts)

  def transaction(fun_or_multi, opts \\ []), do: trace(fn -> Repo.transaction(fun_or_multi, opts) end, opts)

  def update(changeset, opts \\ []), do: trace(fn -> Repo.update(changeset, opts) end, opts)

  def update!(changeset, opts \\ []), do: trace(fn -> Repo.update!(changeset, opts) end, opts)

  def update_all(queryable, updates, opts \\ []), do: trace(fn -> Repo.update_all(queryable, updates, opts) end, opts)

  def trace(func, opts) do
    location = opts[:location] || "query"

    if Tracer.current_trace_id() do
      _ = Tracer.start_span(location)

      response = func.()

      _ = Tracer.finish_span()

      response
    else
      _ = Tracer.start_trace(location)

      response = func.()

      _ = Tracer.finish_trace()

      response
    end
  end
end
