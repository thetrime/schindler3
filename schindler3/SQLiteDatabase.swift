//
//  SQLiteDatabase.swift
//  schindler3
//
//  Created by Matt Lilley on 25/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import Foundation
import SQLite3;

class SQLiteDatabase {
    private var db: OpaquePointer?;

    init (file: String) {
        let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(file)
        /* This next clump deletes the entire DB */
        print("Filename: \(fileURL.path)");
        let freshDB = true
        if (freshDB) {
            do {
                let path = fileURL.path;
                try FileManager.default.removeItem(atPath:path);
            } catch let error as NSError {
                print("Ooops! Something went wrong: \(error)")
            }
        }
        
        /* End clump */
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("error opening database");
        }
    }
    
    private func printLastError(_ context: String) {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        print("error in \(context): \(errmsg)")
    }
    
    private func makeWhereClause(_ w: [String:Any]) -> (String, [Any]) {
        if (w.count > 0) {
            var params: [Any] = [];
            var clauses: [String] = [];
            for (name, value) in w {
                clauses.append("\(name) = ?");
                params.append(value);
            }
            return ("WHERE \(clauses.joined(separator: " AND "))", params)
        }
        return ("", []);
    }
    private func makeOrderClause(_ o: [String:String]) -> String {
        if (o.count > 0) {
            var clauses: [String] = [];
            for (name, direction) in o {
                clauses.append("\(name) \(direction)");
            }
            return "ORDER BY \(clauses.joined(separator: ", "))"
        }
        return "";
    }
    
    private func bindValues(_ stmt:OpaquePointer?, _ from: Int32, _ values: [Any]) {
        var i : Int32 = from;
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self);
        for value in values {
            if let v = value as? String {
                if sqlite3_bind_text(stmt, i+1, v, -1, SQLITE_TRANSIENT) != SQLITE_OK {
                    printLastError("bindValues");
                    return;
                }
            } else if let v = value as? Int {
                if sqlite3_bind_int(stmt, i+1, Int32(v)) != SQLITE_OK {
                    printLastError("bindValues");
                    return;
                }
            } else if let v = value as? Int32 {
                if sqlite3_bind_int(stmt, i+1, v) != SQLITE_OK {
                    printLastError("bindValues");
                    return;
                }
            } else if let v = value as? Int64 {
                if sqlite3_bind_int64(stmt, i+1, v) != SQLITE_OK {
                    printLastError("bindValues");
                    return;
                }
            } else if let v = value as? Double {
                if sqlite3_bind_double(stmt, i+1, v) != SQLITE_OK {
                    printLastError("bindValues");
                    return;
                }
            } else {
                print("Unknown type for \(value) with type \(type(of: value))");
            }
            i += 1;
        }
    }
    
    public func createTable(named name: String, withColumns specs: [String:String], andUniqueConstraints constraints:[[String]] = []) {
        var columns: [String] = [];
        var stmt:OpaquePointer?;
        for (name, type) in specs {
            columns.append("\(name) \(type)")
        }
        for columnList in constraints {
            var constraint : [String] = []
            for column in columnList {
                constraint.append(column)
            }
            columns.append("UNIQUE(\(constraint.joined(separator: ", ")))")
        }
        print("CREATE TABLE IF NOT EXISTS \(name) (\(columns.joined(separator: ", ")))");
        if sqlite3_prepare(db, "CREATE TABLE IF NOT EXISTS \(name) (\(columns.joined(separator: ", ")))", -1, &stmt, nil) != SQLITE_OK {
            printLastError("createTable");
            return;
        }
        if sqlite3_step(stmt) != SQLITE_DONE {
            printLastError("createTable");
            return;
        }
        print("Created table \(name)");
    }
    
    func delete(from table: String, where w:[String:Any] = [:]) {
        var stmt:OpaquePointer?;
        let (whereClause, whereParameters) = makeWhereClause(w);
        print("DELETE FROM \(table) \(whereClause)")
        if sqlite3_prepare(db, "DELETE FROM \(table) \(whereClause)", -1, &stmt, nil) != SQLITE_OK {
            printLastError("delete");
            return;
        }
        bindValues(stmt, 0, whereParameters);
        if sqlite3_step(stmt) != SQLITE_DONE {
            printLastError("delete");
            return;
        }
        print("Deleted from \(table)");
    }
    
    func update(_ table: String, set values:[String: Any], where w:[String:Any] = [:]) {
        var stmt:OpaquePointer?;
        let (whereClause, whereParameters) = makeWhereClause(w);
        var setClauses: [String] = [];
        for (name, value) in values {
            setClauses.append("\(name) = \(value)");
        }
        let setValues = setClauses.joined(separator: ", ");
        if sqlite3_prepare(db, "UPDATE \(table) SET \(setValues) \(whereClause)", -1, &stmt, nil) != SQLITE_OK {
            printLastError("update");
            return;
        }
        bindValues(stmt, 0, whereParameters);
        if sqlite3_step(stmt) != SQLITE_DONE {
            printLastError("update");
            return;
        }
        print("Updated table \(table)");
    }
    
    
    
    func select(from table: String, values:[String], where w:[String:Any] = [:], orderBy o:[String:String] = [:]) -> [[String:Any]] {
        var stmt:OpaquePointer?;
        let (whereClause, whereParameters) = makeWhereClause(w);
        let orderClause = makeOrderClause(o);
        print("SELECT \(values.joined(separator: ",")) FROM \(table) \(whereClause) \(orderClause)")
        if sqlite3_prepare(db, "SELECT \(values.joined(separator: ",")) FROM \(table) \(whereClause) \(orderClause)", -1, &stmt, nil) != SQLITE_OK {
            printLastError("select")
            return [[:]];
        }
        bindValues(stmt, 0, whereParameters);
        var rows: [[String:Any]] = [];
        while(sqlite3_step(stmt) == SQLITE_ROW) {
            var row: [String:Any] = [:];
            var i: Int32 = 0;
            for item in values {
                switch(sqlite3_column_type(stmt, i)) {
                case SQLITE_INTEGER:
                    row[item] = (sqlite3_column_int64(stmt, i) as NSNumber).int64Value;
                case SQLITE_FLOAT:
                    row[item] = sqlite3_column_double(stmt, i);
                case SQLITE_TEXT:
                    row[item] = String(cString: sqlite3_column_text(stmt, i));
                case SQLITE_BLOB:
                    row[item] = nil;
                case SQLITE_NULL:
                    row[item] = nil;
                default:
                    row[item] = nil;
                }
                i+=1;
            }
            rows.append(row);
        }
        return rows;
    }
    
    @discardableResult func insert(to table: String, values v:[String: Any]) -> Int64 {
        var stmt: OpaquePointer?;
        var names: [String] = [];
        var values: [Any] = [];
        for (name, value) in v {
            names.append(name);
            values.append(value);
        }
        let columnNames = names.joined(separator: ",");
        let questionMarks = Array(repeating: "?", count: names.count).joined(separator: ",");
        // Note that we use REPLACE INTO instead of INSERT INTO to simplify getting out-of-band messages that would insert duplicate values
        print("REPLACE INTO \(table)(\(columnNames)) VALUES(\(questionMarks)) -> \(values)")
        if sqlite3_prepare(db, "REPLACE INTO \(table)(\(columnNames)) VALUES(\(questionMarks))", -1, &stmt, nil) != SQLITE_OK {
            printLastError("insert");
            return -1;
        }
        bindValues(stmt, 0, values);
        if sqlite3_step(stmt) != SQLITE_DONE {
            printLastError("insert");
            return -1;
        }
        print("Insert into \(table)")
        return sqlite3_last_insert_rowid(db);
    }
}
