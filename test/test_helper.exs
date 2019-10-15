ExUnit.configure(
  formatters:
    if System.get_env("CI") do
      [JUnitFormatter, ExUnit.CLIFormatter]
    else
      [ExUnit.CLIFormatter]
    end
)

:application.ensure_all_started(:opencensus)
:application.ensure_all_started(:telemetry)
{:ok, _pid} = Opencensus.TestSupport.MetricsCaptureExporter.start_link()
ExUnit.start()
