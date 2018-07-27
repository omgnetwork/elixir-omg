defmodule OmiseGO.API.LoggerExt do
  @moduledoc """
  Module provides extenssion point over default logging functionality. However we allow changes only in development
  environment for debugging purposes. No changes to this module can be committed to the main branch ever!

  We assume all logging functionality in application code is provided only by this module. We want to keep logging
  impossible to break application, therefore we based it on standard Logger module. Keep it simple and stupid.

  Four logging levels are understanded as follows:
   * error - use when application is about to crash to provide specific failure reason
   * warn  - something went bad and might cause application to crash, e.g. misconfiguration
   * info  - logs most important, not frequent, concise messages, e.g. modules starting. Enabled for production env.
   * debug - most likely default option for everything but above.

  We assume that the logged message:
   * is logged in lazy way (you shall provide function not a string to the Logger function)
   * is single-lined, so does not use witespaces other than space (?\s)
   * all string interpolated data are inspected ("... \#{inspect data} ...")

  Please help us keep logging as simple and borring as possible
  """
  @inspect_opt [
    pretty: true,
    width: 120,
    syntax_colors: [
      number: "\e[38;2;97;175;239m",
      atom: "\e[38;2;86;182;194m",
      tuple: :light_magenta,
      map: :light_white,
      list: :light_green
    ]
  ]

  defmacro __using__(_opt) do
    quote do
      require Logger

      # Uncommenting following code with replace Kernel.inspect/1 function with your own implementation.
      # Before uncommenting please ensure no changes will be committed to the main branch (e.g add fix-me).
      # import Kernel, except: [inspect: 1]
      # def inspect(term), do: Kernel.inspect(term, unquote(@inspect_opt))
    end
  end

  defp level_to_colors(:debug), do: {{0, 0, 0}, {40, 44, 52}}
  defp level_to_colors(:info), do: {{140, 172, 0}, {20, 60, 80}}
  defp level_to_colors(:warn), do: {{204, 140, 0}, {224, 160, 0}}
  defp level_to_colors(:error), do: {{220, 20, 20}, {60, 0, 0}}

  defp background(str, {r, g, b}),
    do: String.replace(IO.ANSI.reset() <> str, IO.ANSI.reset(), "\e[48;2;#{r};#{g};#{b}m") <> IO.ANSI.reset()

  defp text_color({r, g, b}), do: "\e[38;2;#{r};#{g};#{b}m"

  defp get_metadata_as_string(metadata, atom) do
    case Keyword.get(metadata, atom) do
      nil -> ""
      value -> inspect(value)
    end
  end

  def format(level, message, _timestamp, metadata) do
    {darker, lighter} = level_to_colors(level)
    message = if is_binary(message) and String.printable?(message), do: message, else: inspect(message, @inspect_opt)

    background(
      text_color({230, 230, 230}) <>
        Atom.to_string(level) <>
        " " <> get_metadata_as_string(metadata, :module) <> ":" <> get_metadata_as_string(metadata, :line) <> "\t",
      darker
    ) <> background(text_color({240, 240, 240}) <> message, lighter) <> "\n"
  rescue
    msg -> "could not format: #{inspect(msg)}\n#{inspect({level, message, metadata}, @inspect_opt)})"
  end
end
