#!/usr/bin/env python3
"""
setup.py - Generates Dart SQLite Models and DatabaseHelper for Flutter project from schema.json

Usage:
    python setup.py [--schema SCHEMA_PATH] [--output-dir DART_LIB_DIR]

Options:
    -s, --schema PATH        Path to schema.json input file (default: schema.json)
    -o, --output-dir PATH    Path to Flutter lib directory (default: frontend/lib)
"""

import os
import sys
import json
import argparse
from typing import Dict, Any, List

# Helper naming functions
def snake_to_pascal(name: str) -> str:
    singular_map = {
        "roles": "Role",
        "users": "User",
        "patients": "Patient",
        "patient_visits": "PatientVisit",
        "vital_signs": "VitalSign",
        "investigations": "Investigation",
        "diagnoses": "Diagnosis",
        "prescriptions": "Prescription",
        "referrals": "Referral",
        "bills": "Bill",
        "bill_items": "BillItem",
        "audit_logs": "AuditLog",
        "sync_queue": "SyncQueue"
    }
    if name in singular_map:
        return singular_map[name]
    if name.endswith("s") and not name.endswith("ss"):
        name = name[:-1]
    return "".join(word.capitalize() for word in name.split("_"))

def snake_to_camel(name: str) -> str:
    words = name.split("_")
    return words[0] + "".join(word.capitalize() for word in words[1:])

def sql_type_to_dart(sql_type: str, is_nullable: bool) -> str:
    sql_type_upper = sql_type.upper()
    if "INT" in sql_type_upper:
        d_type = "int"
    elif "REAL" in sql_type_upper or "FLOAT" in sql_type_upper or "DOUBLE" in sql_type_upper:
        d_type = "double"
    elif "BLOB" in sql_type_upper:
        d_type = "Uint8List"
    else:
        d_type = "String"
    
    return f"{d_type}?" if is_nullable else d_type

def build_column_sql(col: Dict[str, Any]) -> str:
    parts = [f'"{col["name"]}"', col["type"]]
    if col.get("primary_key"):
        parts.append("PRIMARY KEY")
        if col.get("auto_increment"):
            parts.append("AUTOINCREMENT")
    if col.get("not_null"):
        parts.append("NOT NULL")
    if col.get("unique"):
        parts.append("UNIQUE")
    if "default" in col and col["default"] is not None:
        parts.append(f"DEFAULT {col['default']}")
    return " ".join(parts)

def build_foreign_key_sql(fk: Dict[str, Any]) -> str:
    sql = f'FOREIGN KEY ("{fk["column"]}") REFERENCES "{fk["references_table"]}" ("{fk["references_column"]}")'
    if fk.get("on_delete"):
        sql += f' ON DELETE {fk["on_delete"]}'
    if fk.get("on_update"):
        sql += f' ON UPDATE {fk["on_update"]}'
    return sql

def generate_ddl_statements(schema: Dict[str, Any]) -> List[str]:
    statements = []
    for table in schema.get("tables", []):
        table_name = table["name"]
        clauses = []
        for col in table.get("columns", []):
            clauses.append("  " + build_column_sql(col))
        for fk in table.get("foreign_keys", []):
            clauses.append("  " + build_foreign_key_sql(fk))
        table_ddl = f'CREATE TABLE IF NOT EXISTS "{table_name}" (\n' + ",\n".join(clauses) + "\n);"
        statements.append(table_ddl)
        
        for idx in table.get("indexes", []):
            unique_str = "UNIQUE " if idx.get("unique") else ""
            cols_str = ", ".join([f'"{c}"' for c in idx["columns"]])
            idx_ddl = f'CREATE {unique_str}INDEX IF NOT EXISTS "{idx["name"]}" ON "{table_name}" ({cols_str});'
            statements.append(idx_ddl)
    return statements

def generate_dart_files(schema: Dict[str, Any], frontend_lib_dir: str):
    """Generate Flutter Dart Models and DatabaseHelper service from schema JSON."""
    models_dir = os.path.join(frontend_lib_dir, "models")
    db_dir = os.path.join(frontend_lib_dir, "database")
    os.makedirs(models_dir, exist_ok=True)
    os.makedirs(db_dir, exist_ok=True)
    
    has_blob = any(
        "BLOB" in col["type"].upper()
        for t in schema.get("tables", [])
        for col in t.get("columns", [])
    )
    
    # -------------------------------------------------------------
    # 1. Generate models.dart
    # -------------------------------------------------------------
    models_code = [
        "// AUTO-GENERATED FILE FROM schema.json via setup.py - DO NOT MODIFY DIRECTLY",
    ]
    if has_blob:
        models_code.append("import 'dart:typed_data';")
    models_code.append("")
    
    for table in schema.get("tables", []):
        table_name = table["name"]
        class_name = snake_to_pascal(table_name)
        
        fields = []
        for col in table["columns"]:
            c_name = col["name"]
            c_camel = snake_to_camel(c_name)
            is_pk = col.get("primary_key", False)
            not_null = col.get("not_null", False)
            is_nullable = not not_null or is_pk or "default" in col
            dart_type = sql_type_to_dart(col["type"], is_nullable)
            fields.append({
                "sql_name": c_name,
                "camel_name": c_camel,
                "dart_type": dart_type,
                "is_nullable": is_nullable
            })
            
        models_code.append(f"class {class_name} {{")
        
        # Class Properties
        for f in fields:
            models_code.append(f"  final {f['dart_type']} {f['camel_name']};")
        models_code.append("")
        
        # Constructor
        models_code.append(f"  const {class_name}({{")
        for f in fields:
            req_prefix = "" if f["is_nullable"] else "required "
            models_code.append(f"    {req_prefix}this.{f['camel_name']},")
        models_code.append("  });")
        models_code.append("")
        
        # fromMap factory
        models_code.append(f"  factory {class_name}.fromMap(Map<String, dynamic> map) {{")
        models_code.append(f"    return {class_name}(")
        for f in fields:
            sql_n = f['sql_name']
            if "double" in f["dart_type"]:
                val_expr = f"map['{sql_n}'] != null ? (map['{sql_n}'] as num).toDouble() : null" if f["is_nullable"] else f"(map['{sql_n}'] as num).toDouble()"
            elif "int" in f["dart_type"]:
                val_expr = f"map['{sql_n}'] != null ? (map['{sql_n}'] as num).toInt() : null" if f["is_nullable"] else f"(map['{sql_n}'] as num).toInt()"
            elif "String" in f["dart_type"]:
                val_expr = f"map['{sql_n}'] as String?" if f["is_nullable"] else f"map['{sql_n}'] as String"
            else:
                val_expr = f"map['{sql_n}']"
            models_code.append(f"      {f['camel_name']}: {val_expr},")
        models_code.append("    );")
        models_code.append("  }")
        models_code.append("")
        
        # toMap method
        models_code.append("  Map<String, dynamic> toMap() {")
        models_code.append("    return {")
        for f in fields:
            models_code.append(f"      '{f['sql_name']}': {f['camel_name']},")
        models_code.append("    };")
        models_code.append("  }")
        models_code.append("")
        
        # copyWith method
        models_code.append(f"  {class_name} copyWith({{")
        for f in fields:
            raw_type = f["dart_type"].rstrip("?")
            models_code.append(f"    {raw_type}? {f['camel_name']},")
        models_code.append("  }) {")
        models_code.append(f"    return {class_name}(")
        for f in fields:
            models_code.append(f"      {f['camel_name']}: {f['camel_name']} ?? this.{f['camel_name']},")
        models_code.append("    );")
        models_code.append("  }")
        
        models_code.append("}\n")
        
    models_path = os.path.join(models_dir, "models.dart")
    with open(models_path, "w", encoding="utf-8") as f:
        f.write("\n".join(models_code))
    print(f"  [+] Generated Dart model classes: {models_path}")
    
    # -------------------------------------------------------------
    # 2. Generate database_helper.dart
    # -------------------------------------------------------------
    ddl_statements = generate_ddl_statements(schema)
    
    db_code = [
        "// AUTO-GENERATED FILE FROM schema.json via setup.py - DO NOT MODIFY DIRECTLY",
        "import 'dart:io';",
        "import 'package:path/path.dart';",
        "import 'package:sqflite_common_ffi/sqflite_ffi.dart';",
        "import '../models/models.dart';",
        "",
        "class DatabaseHelper {",
        "  static final DatabaseHelper instance = DatabaseHelper._init();",
        "  static Database? _database;",
        "",
        "  DatabaseHelper._init();",
        "",
        "  Future<Database> get database async {",
        "    if (_database != null) return _database!;",
        "    _database = await _initDB('emr.db');",
        "    return _database!;",
        "  }",
        "",
        "  Future<Database> _initDB(String filePath) async {",
        "    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {",
        "      sqfliteFfiInit();",
        "      databaseFactory = databaseFactoryFfi;",
        "    }",
        "",
        "    final dbPath = await getDatabasesPath();",
        "    final path = join(dbPath, filePath);",
        "",
        "    return await openDatabase(",
        "      path,",
        "      version: 1,",
        "      onConfigure: (db) async {",
        "        await db.execute('PRAGMA foreign_keys = ON;');",
        "      },",
        "      onCreate: _createDB,",
        "    );",
        "  }",
        "",
        "  Future<void> _createDB(Database db, int version) async {"
    ]
    
    for stmt in ddl_statements:
        db_code.append(f"    await db.execute('''{stmt}''');")
        
    # Seed initial records inside _createDB
    if "seed_data" in schema:
        db_code.append("    await _seedInitialData(db);")
        
    db_code.append("  }")
    db_code.append("")
    
    # Seed data helper
    if "seed_data" in schema:
        db_code.append("  Future<void> _seedInitialData(Database db) async {")
        for table_name, rows in schema["seed_data"].items():
            for row in rows:
                col_names = ", ".join([f'"{k}"' for k in row.keys()])
                val_items = []
                for v in row.values():
                    if isinstance(v, str):
                        escaped = v.replace("'", "''")
                        val_items.append(f"'{escaped}'")
                    elif v is None:
                        val_items.append("NULL")
                    else:
                        val_items.append(str(v))
                vals_str = ", ".join(val_items)
                db_code.append(f"    await db.execute('''INSERT OR IGNORE INTO \"{table_name}\" ({col_names}) VALUES ({vals_str});''');")
        db_code.append("  }")
        db_code.append("")
    
    # Add CRUD helper methods for each table
    for table in schema.get("tables", []):
        t_name = table["name"]
        cls_name = snake_to_pascal(t_name)
        c_var = cls_name[0].lower() + cls_name[1:]
        
        db_code.append(f"  // === {cls_name} CRUD Operations ===")
        db_code.append(f"  Future<int> insert{cls_name}({cls_name} {c_var}) async {{")
        db_code.append("    final db = await instance.database;")
        db_code.append(f"    return await db.insert('{t_name}', {c_var}.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);")
        db_code.append("  }")
        db_code.append("")
        
        db_code.append(f"  Future<List<{cls_name}>> getAll{cls_name}s() async {{")
        db_code.append("    final db = await instance.database;")
        db_code.append(f"    final result = await db.query('{t_name}');")
        db_code.append(f"    return result.map((json) => {cls_name}.fromMap(json)).toList();")
        db_code.append("  }")
        db_code.append("")
        
        db_code.append(f"  Future<{cls_name}?> get{cls_name}ById(int id) async {{")
        db_code.append("    final db = await instance.database;")
        db_code.append(f"    final maps = await db.query('{t_name}', where: 'id = ?', whereArgs: [id]);")
        db_code.append("    if (maps.isNotEmpty) {")
        db_code.append(f"      return {cls_name}.fromMap(maps.first);")
        db_code.append("    } else {")
        db_code.append("      return null;")
        db_code.append("    }")
        db_code.append("  }")
        db_code.append("")
        
        db_code.append(f"  Future<int> update{cls_name}({cls_name} {c_var}) async {{")
        db_code.append("    final db = await instance.database;")
        db_code.append(f"    return await db.update('{t_name}', {c_var}.toMap(), where: 'id = ?', whereArgs: [{c_var}.id]);")
        db_code.append("  }")
        db_code.append("")
        
        db_code.append(f"  Future<int> delete{cls_name}(int id) async {{")
        db_code.append("    final db = await instance.database;")
        db_code.append(f"    return await db.delete('{t_name}', where: 'id = ?', whereArgs: [id]);")
        db_code.append("  }")
        db_code.append("")

    db_code.append("  Future<void> close() async {")
    db_code.append("    final db = await instance.database;")
    db_code.append("    db.close();")
    db_code.append("  }")
    db_code.append("}")
    
    db_path = os.path.join(db_dir, "database_helper.dart")
    with open(db_path, "w", encoding="utf-8") as f:
        f.write("\n".join(db_code))
    print(f"  [+] Generated Dart DatabaseHelper service: {db_path}")

def main():
    parser = argparse.ArgumentParser(description="Generate Dart SQLite models and helper for Flutter application")
    parser.add_argument("-s", "--schema", default="schema.json", help="Path to schema.json file (default: schema.json)")
    parser.add_argument("-o", "--output-dir", default="frontend/lib", help="Path to Flutter lib directory (default: frontend/lib)")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.schema):
        print(f"Error: Schema file '{args.schema}' not found.", file=sys.stderr)
        sys.exit(1)
        
    with open(args.schema, "r", encoding="utf-8") as f:
        schema = json.load(f)
        
    print(f"Generating Dart SQLite code for '{schema.get('database_name', 'EMR Database')}'...")
    generate_dart_files(schema, args.output_dir)
    print("Done! Dart code generated successfully.")

if __name__ == "__main__":
    main()
