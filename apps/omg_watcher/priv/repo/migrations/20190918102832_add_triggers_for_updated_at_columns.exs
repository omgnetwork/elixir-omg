defmodule OMG.Watcher.DB.Repo.Migrations.AddTriggersForUpdatedAtColumns do
  use Ecto.Migration

  def change do
    execute """
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
          NEW.updated_at = (now() at time zone 'utc');
          RETURN NEW;
      END;
      $$ language 'plpgsql';
    """

    execute """
      CREATE TRIGGER update_txoutputs_updated_at
      BEFORE UPDATE ON txoutputs FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
    """

    execute """
      CREATE TRIGGER update_ethevents_updated_at
      BEFORE UPDATE ON ethevents FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
    """

    execute """
      CREATE TRIGGER update_ethevents_txoutputs_updated_at
      BEFORE UPDATE ON ethevents_txoutputs FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
    """
  end
end
