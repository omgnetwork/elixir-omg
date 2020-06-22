defmodule OMG.WatcherInfo.DB.TraceableRepo do
  alias OMG.WatcherInfo.DB.Repo
  alias OMG.WatcherInfo.Tracer

  def aggregate(queryable, aggregate, opts \\ []), do: span(fn -> Repo.aggregate(queryable, aggregate, opts) end)

  def all(queryable, opts \\ []), do: span(fn -> Repo.aggregate(queryable, opts) end)

  def delete(struct_or_changeset, opts \\ []), do: span(fn -> Repo.delete(struct_or_changeset, opts) end)

  def delete!(struct_or_changeset, opts \\ []), do: span(fn -> Repo.delete!(struct_or_changeset, opts) end)

  def delete_all(queryable, opts \\ []), do: span(fn -> Repo.delete_all(queryable, opts) end)

  def exists?(queryable, opts \\ []), do: span(fn -> Repo.exists?(queryable, opts) end)

  def get(queryable, id, opts \\ []), do: span(fn -> Repo.get(queryable, id, opts) end)

  def get!(queryable, id, opts \\ []), do: span(fn -> Repo.get!(queryable, id, opts) end)

  def get_by(queryable, clauses, opts \\ []), do: span(fn -> Repo.get_by(queryable, clauses, opts) end)

  def get_by!(queryable, clauses, opts \\ []), do: span(fn -> Repo.get_by!(queryable, clauses, opts) end)

  def insert(struct_or_changeset, opts \\ []), do: span(fn -> Repo.insert(struct_or_changeset, opts) end)

  def insert!(struct_or_changeset, opts \\ []), do: span(fn -> Repo.insert!(struct_or_changeset, opts) end)

  def insert_all(schema_or_source, entries, opts \\ []),
    do: span(fn -> Repo.insert_all(schema_or_source, entries, opts) end)

  def insert_or_update(changeset, opts \\ []), do: span(fn -> Repo.insert_or_update(changeset, opts) end)

  def insert_or_update!(changeset, opts \\ []), do: span(fn -> Repo.insert_or_update!(changeset, opts) end)

  def load(module_or_map, data), do: span(fn -> Repo.load(module_or_map, data) end)

  def one(queryable, opts \\ []), do: span(fn -> Repo.one(queryable, opts) end)

  def one!(queryable, opts \\ []), do: span(fn -> Repo.one!(queryable, opts) end)

  def preload(structs_or_struct_or_nil, preloads, opts \\ []),
    do: span(fn -> Repo.preload(structs_or_struct_or_nil, preloads, opts) end)

  def rollback(value), do: span(fn -> Repo.rollback(value) end)

  def stream(queryable, opts \\ []), do: span(fn -> Repo.stream(queryable, opts) end)

  def transaction(fun_or_multi, opts \\ []), do: span(fn -> Repo.transaction(fun_or_multi, opts) end)

  def update(changeset, opts \\ []), do: span(fn -> Repo.update(changeset, opts) end)

  def update!(changeset, opts \\ []), do: span(fn -> Repo.update!(changeset, opts) end)

  def update_all(queryable, updates, opts \\ []), do: span(fn -> Repo.update_all(queryable, updates, opts) end)

  def span(func) do
    if Tracer.current_trace_id() do
      func.()
    else
      _ = Tracer.start_trace("query")

      response = func.()

      _ = Tracer.finish_trace()

      response
    end
  end
end
