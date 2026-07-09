SimpleCov.start "rails" do
  enable_coverage :branch

  minimum_coverage 90
  minimum_coverage_by_file 80

  refuse_coverage_drop

  track_files "{app,lib}/**/*.rb"

  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"
end
