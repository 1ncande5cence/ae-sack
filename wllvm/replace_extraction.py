import importlib.util
import wllvm
import os
import shutil

spec = importlib.util.find_spec("wllvm")
package_dir = os.path.dirname(spec.origin)
print(package_dir)
shutil.copy("/ae-sack/wllvm/extraction.py", package_dir)