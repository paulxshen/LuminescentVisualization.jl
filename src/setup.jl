using Pkg
ENV["PYTHON"]
Pkg.build("PyCall")
Pkg.add(url="https://github.com/HelgeGehring/femwell")
# python -m pip install femwell