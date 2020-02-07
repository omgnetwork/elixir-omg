defmodule Credo.Check.Warning.LicenseHeader do
  @moduledoc """
  Checks whether license header has been included in every file, except those where it shouldn't be

  **Doesn't** check the correctness of the header, just that it exists, so it checks first line to say `# Copyright`
  """

  @explanation [
    check: @moduledoc
  ]

  # you can configure the basics of your check via the `use Credo.Check` call
  use Credo.Check, base_priority: :high, category: :custom, exit_status: 1

  @doc false
  def run(%SourceFile{filename: source_path} = source_file, params \\ []) do
    # we ignore config, mix.exs and migration files, so all of these return no issues, i.e. []
    case Path.split(source_path) do
      ["apps", _, "config" | _] -> []
      ["config" | _] -> []
      ["mix.exs"] -> []
      ["apps", _, "mix.exs" | _] -> []
      ["apps", _, "priv" , "repo" | _] -> []
      _ -> do_run(source_file, params)
    end
  end

  defp do_run(source_file, params) do
    lines = SourceFile.lines(source_file)
    {1, first_line} = hd(lines)

    # IssueMeta helps us pass down both the source_file and params of a check
    # run to the lower levels where issues are created, formatted and returned
    issue_meta = IssueMeta.for(source_file, params)

    if String.starts_with?(first_line, "# Copyright") do
      []
    else
      trigger = first_line
      new_issue = issue_for(issue_meta, 1, trigger)
      [new_issue]
    end
  end

  defp issue_for(issue_meta, line_no, trigger) do
    # format_issue/2 is a function provided by Credo.Check to help us format the
    # found issue
    format_issue issue_meta,
      message: "File is missing a license header, make sure to include the license header as other files do",
      line_no: line_no,
      trigger: trigger
  end
end
