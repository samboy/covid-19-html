This is where examine-growth.lua puts files used by GNUplot to make
graphs.  The graphs show COVID-19 growth for the US as a while, a
given state, or a given county.

# How to make graphs for each state and county in the US

Needed 

- Git
- Lua
- Gnuplot
- Bash (Windows users: Install Cygwin)

In the parent directory:

```bash
git clone https://github.com/nytimes/covid-19-data/
cp covid-19-data/us-counties.csv data.csv
lua examine-growth.lua gnuplot
cd GNUplot/
for FILE in *gnuplot ; do
  gnuplot "$FILE"
  echo "$FILE"
done
cp USA.html index.html
```

Once the New York Times repo is cloned:

```bash
cd covid-19-data/
git pull origin master
cd ..
cp covid-19-data/us-counties.csv data.csv
lua examine-growth.lua gnuplot
cd GNUplot/
for FILE in *gnuplot ; do
  gnuplot "$FILE"
  echo "$FILE"
done
cp USA.html index.html
```

The Lua script makes the .html files and the files needed to make
the PNG graphs.  Gnuplot makes the physical PNG files.
