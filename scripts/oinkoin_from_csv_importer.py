import csv
import json
import time
import random
import re
import sys
from datetime import datetime

# --- Utility Functions ---

def parse_money(value):
    if value is None: return 0.0
    val_str = str(value).strip()
    if not val_str: return 0.0
    clean_val = re.sub(r'[^\d,.-]', '', val_str)
    if ',' in clean_val and '.' in clean_val:
        if clean_val.find('.') < clean_val.find(','):
            clean_val = clean_val.replace('.', '').replace(',', '.')
    elif ',' in clean_val:
        clean_val = clean_val.replace(',', '.')
    try:
        return float(clean_val)
    except ValueError:
        return None

_DATE_FORMATS = [
    '%Y-%m-%d %H:%M:%S',
    '%d/%m/%Y %H:%M:%S',
    '%m/%d/%Y %H:%M:%S',
    '%d-%m-%Y %H:%M:%S',
    '%d.%m.%Y %H:%M:%S',
    '%Y/%m/%d %H:%M:%S',
    '%d/%m/%Y',
    '%m/%d/%Y',
    '%d-%m-%Y',
    '%d.%m.%Y',
    '%Y/%m/%d',
]

def _parse_date_string(val_str):
    try:
        return datetime.fromisoformat(val_str)
    except ValueError:
        pass
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(val_str, fmt)
        except ValueError:
            continue
    raise ValueError(f"Unable to parse date: {val_str}")

def parse_to_ms(date_val):
    if not date_val: return None
    val_str = str(date_val).strip()
    try:
        num = float(val_str)
        return int(num * 1000) if num < 10000000000 else int(num)
    except:
        pass
    try:
        return int(_parse_date_string(val_str).timestamp() * 1000)
    except:
        return None

def generate_oinkoin_color():
    return f"255:{random.randint(50,255)}:{random.randint(50,255)}:{random.randint(50,255)}"

def print_dual_preview(mapping, sample_row):
    print("\n" + "═"*80)
    print(" PREVIEW: MAPPING COMPARISON")
    print("═"*80)
    
    headers = list(sample_row.keys())
    values = [str(sample_row[h]) for h in headers]
    widths = [max(len(h), len(v)) + 2 for h, v in zip(headers, values)]
    
    print("\n[ORIGINAL CSV ROW]")
    print("┌─" + "─┬─".join("─" * w for w in widths) + "─┐")
    print("│ " + " │ ".join(h.ljust(w) for h, w in zip(headers, widths)) + " │")
    print("├─" + "─┼─".join("─" * w for w in widths) + "─┤")
    print("│ " + " │ ".join(v.ljust(w) for v, w in zip(values, widths)) + " │")
    print("└─" + "─┴─".join("─" * w for w in widths) + "─┘")

    val = parse_money(sample_row.get(mapping['value'])) if mapping['value'] else 0.0
    ms = parse_to_ms(sample_row.get(mapping['datetime'])) if mapping['datetime'] else None
    readable_date = datetime.fromtimestamp(ms/1000.0).strftime('%Y-%m-%d %H:%M:%S') if ms else "N/A"
    
    cat_type = 0 if (val is not None and val < 0) else 1
    get_strict = lambda field: sample_row.get(mapping[field]) if mapping.get(field) else None

    # Process tags for the preview
    tag_preview = []
    raw_tags = get_strict('tags')
    if raw_tags:
        tag_list = [t.strip() for t in re.split(r'[;,]', str(raw_tags)) if t.strip()]
        tag_preview = [{"record_id": 1, "tag_name": t} for t in tag_list]

    preview_rec = {
        "id": 1,
        "title": get_strict('title'),
        "value": val,
        "datetime": ms,
        "timezone": "Europe/Vienna",
        "category_name": get_strict('category_name') or "Uncategorized",
        "category_type": cat_type,
        "icon": 63,
        "description": get_strict('description')
    }
    
    print(f"\n[INTERPRETED DATE]: {readable_date}")
    print("\n[RESULTING OINKOIN JSON]")
    print(json.dumps(preview_rec, indent=2))
    
    print("\n[RESULTING TAG ASSOCIATIONS]")
    if tag_preview:
        print(json.dumps(tag_preview, indent=2))
    else:
        print("  null (No tags mapped or found)")
    print("\n" + "═"*80)

# --- Main Logic ---

def start_interactive_session(csv_path):
    try:
        with open(csv_path, mode='r', encoding='utf-8-sig') as f:
            content = f.read(4096)
            dialect = csv.Sniffer().sniff(content) if any(c in content for c in ',;') else 'excel'
            f.seek(0)
            reader = list(csv.DictReader(f, dialect=dialect))
    except Exception as e:
        print(f"Error reading file: {e}")
        return

    headers = list(reader[0].keys())
    mapping = {
        "title": next((h for h in headers if any(s == h.lower() for s in ["title", "name"])), None),
        "value": next((h for h in headers if any(s in h.lower() for s in ["money", "amount", "value"])), None),
        "datetime": next((h for h in headers if any(s in h.lower() for s in ["date", "time", "timestamp"])), None),
        "category_name": next((h for h in headers if any(s == h.lower() for s in ["category", "categoria"])), None),
        "description": next((h for h in headers if any(s in h.lower() for s in ["description", "note", "memo"])), None),
        "tags": next((h for h in headers if any(s in h.lower() for s in ["tags", "tag", "labels"])), None)
    }

    while True:
        print("\nSTEP 1: VERIFY COLUMN MAPPING")
        for k, v in mapping.items():
            status = f"──▶ [{v}]" if v else "──▶ [STRICT NULL]"
            print(f"{k.ljust(15)} {status}")
        
        print_dual_preview(mapping, reader[0])

        choice = input("\n[y] Confirm | [n] Edit Field | [q] Quit: ").lower()
        if choice == 'y': break
        elif choice == 'q': sys.exit()
        elif choice == 'n':
            field = input("\nWhich field to re-map? ").strip()
            if field in mapping:
                print(f"Available columns: {headers}")
                val = input(f"Enter CSV column for '{field}' (leave empty for NULL): ").strip()
                mapping[field] = val if val in headers else None

    # SCANNING SUMMARY
    print("\n" + "█"*40)
    print(" STEP 2: SCANNING DATA SUMMARY")
    print("█"*40)
    
    success_count, unique_categories, unique_tags, timestamps = 0, set(), set(), []

    for idx, row in enumerate(reader):
        val = parse_money(row.get(mapping['value'])) if mapping['value'] else 0.0
        ms = parse_to_ms(row.get(mapping['datetime'])) if mapping['datetime'] else None
        cat = row.get(mapping['category_name']) if mapping['category_name'] else "Uncategorized"
        
        if val is not None and ms is not None:
            success_count += 1
            unique_categories.add(cat)
            timestamps.append(ms)
            if mapping['tags'] and row.get(mapping['tags']):
                tags = [t.strip() for t in re.split(r'[;,]', str(row[mapping['tags']])) if t.strip()]
                unique_tags.update(tags)

    print(f"✅ Records Processed:   {success_count}")
    print(f"📂 Unique Categories:   {len(unique_categories)}")
    print(f"🏷️  Unique Tags Found:   {len(unique_tags)}")
    if timestamps:
        print(f"📅 Date Range:         {datetime.fromtimestamp(min(timestamps)/1000.0).strftime('%Y-%m-%d')} to {datetime.fromtimestamp(max(timestamps)/1000.0).strftime('%Y-%m-%d')}")

    # FINAL EXPORT
    if input("\nExport to Oinkoin JSON? (y/n): ").lower() == 'y':
        processed_records, categories_map, tag_associations = [], {}, []

        for row in reader:
            val = parse_money(row.get(mapping['value'])) if mapping['value'] else 0.0
            ms_time = parse_to_ms(row.get(mapping['datetime'])) if mapping['datetime'] else int(time.time()*1000)
            get_row_val = lambda f: row.get(mapping[f]) if mapping.get(f) else None
            cat_name = get_row_val('category_name') or "Uncategorized"
            c_type = 0 if val < 0 else 1
            
            if cat_name not in categories_map:
                categories_map[cat_name] = {
                    "name": cat_name, "category_type": c_type,
                    "last_used": ms_time, "record_count": 0, "color": generate_oinkoin_color(),
                    "is_archived": 0, "sort_order": len(categories_map), "icon": 63
                }
            
            categories_map[cat_name]["record_count"] += 1
            processed_records.append({
                "title": get_row_val('title'),
                "value": val, 
                "datetime": ms_time, 
                "timezone": "Europe/Vienna",
                "category_name": cat_name, 
                "category_type": c_type,
                "description": get_row_val('description'),
                "recurrence_id": None, 
                "raw_tags": get_row_val('tags')
            })

        processed_records.sort(key=lambda x: x['datetime'])
        for i, r in enumerate(processed_records):
            rec_id = i + 1
            raw_tags = r.pop("raw_tags")
            r["id"] = rec_id
            if raw_tags:
                for t in re.split(r'[;,]', str(raw_tags)):
                    if t.strip(): tag_associations.append({"record_id": rec_id, "tag_name": t.strip()})

        output = {
            "records": processed_records,
            "categories": sorted(categories_map.values(), key=lambda c: c["name"]),
            "recurrent_record_patterns": [],
            "record_tag_associations": tag_associations,
            "created_at": int(time.time() * 1000),
            "package_name": "com.github.emavgl.piggybankpro", 
            "version": "1.2.1", "database_version": "16"
        }

        with open('oinkoin_import.json', 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2)
        print(f"\nSuccess! 'oinkoin_import.json' created.")

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else input("Enter CSV path: ")
    start_interactive_session(path.strip("'\" "))
