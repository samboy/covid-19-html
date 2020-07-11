This is where examine-growth.lua puts files used by GNUplot to make
graphs.

# How to make lots of graphs

Needed 

- Lua
- Gnuplot
- Bash (Windows users: Install Cygwin)

In the parent directory:

```bash
lua examine-growth.lua gnuplot
cd GNUplot
for FILE in *gnuplot ; do
  gnuplot "$FILE"
  echo "$FILE"
done
```

The Lua script makes the .html files and the files needed to make
the PNG graphs.  Gnuplot makes the physical PNG files.
