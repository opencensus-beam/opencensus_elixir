# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

if Mix.env() == :test do
  config :junit_formatter,
    report_file: "report.xml",
    report_dir: "reports/exunit"

  config :opencensus,
    reporters: [{Opencensus.TestSupport.SpanCaptureReporter, []}],
    send_interval_ms: 0
end
