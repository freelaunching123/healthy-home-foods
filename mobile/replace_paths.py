import os

folder = r"e:\healthy-home-foods-main\mobile\lib\features\admin\widgets\reports"
for filename in os.listdir(folder):
    if filename.endswith(".dart"):
        filepath = os.path.join(folder, filename)
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        
        new_content = content.replace("'/api/v1/reports/", "'/reports/")
        if new_content != content:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(new_content)
            print(f"Updated {filename}")
print("Done")
