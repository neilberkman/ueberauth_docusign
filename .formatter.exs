[
  import_deps: [:ueberauth, :plug],
  plugins: [Quokka],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 100,
  quokka: [
    # Enable all Quokka features
    autosort: [:map, :defstruct],
    exclude: [],
    only: [
      :blocks,
      :comment_directives,
      :configs,
      :defs,
      :deprecations,
      :module_directives,
      :pipes,
      :single_node
    ]
  ]
]
