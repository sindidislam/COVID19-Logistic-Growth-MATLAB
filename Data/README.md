# Dataset Documentation & Setup

This directory contains the COVID-19 dataset and processed benchmarks used for logistic growth modeling and parameter estimation.

---

## 1. Files Included

| File | Description | Size |
| :--- | :--- | :--- |
| `owid-covid-data.zip` | Complete global COVID-19 dataset from Our World in Data (compressed to bypass GitHub's 100 MB limit) | ~10.6 MB |
| `bangladesh_covid_processed.csv` | Cleaned cumulative case counts and timeline for Bangladesh (1,674 records) ready for immediate execution | ~39.6 KB |

---

## 2. Dataset Source & Attribution

- **Source**: [Our World in Data (OWID) COVID-19 Dataset](https://ourworldindata.org/coronavirus)
- **Official Repository**: [github.com/owid/covid-19-data](https://github.com/owid/covid-19-data)
- **Direct Download (Raw CSV)**:
  ```url
  https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/owid-covid-data.csv
  ```

---

## 3. How to Extract the Full Dataset

The MATLAB scripts in `Code/` (`loading_csv.m`) are designed to automatically detect `owid-covid-data.zip` and extract it if `owid-covid-data.csv` is not already present.

If you prefer to extract it manually:

### Option A: Using PowerShell (Windows)
```powershell
Expand-Archive -Path Data/owid-covid-data.zip -DestinationPath Data/
```

### Option B: Using Command Line (Linux/macOS)
```bash
unzip Data/owid-covid-data.zip -d Data/
```

### Option C: Using MATLAB
```matlab
unzip('Data/owid-covid-data.zip', 'Data');
```

> [!NOTE]
> `Data/owid-covid-data.csv` is listed in `.gitignore` to prevent committing the uncompressed ~103 MB file back to GitHub.
