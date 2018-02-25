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
        /*
        do {
            let path = fileURL.path;
            try FileManager.default.removeItem(atPath:path);
        } catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        }
        */
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
    
    private func bindValues(_ stmt:OpaquePointer?, _ from: Int32, _ values: [Any]) {
        var i : Int32 = from;
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self);
        for value in values {
            if let v = value as? String {
                if sqlite3_bind_text(stmt, i+1, v, -1, SQLITE_TRANSIENT) != SQLITE_OK {
                    printLastError("bindValues");
                    return;
                }
            } else if let v = value as? Int32 {
                if sqlite3_bind_int(stmt, i+1, v) != SQLITE_OK {
                    printLastError("bindValues");
                    return;
                }
            } else if let v = value as? Double {
                if sqlite3_bind_double(stmt, i+1, v) != SQLITE_OK {
                    printLastError("bindValues");
                    return;
                }
            } else {
                print("Unknown type for \(value)");
            }
            i += 1;
        }
    }
    
    public func createTable(named name: String, withColumns specs: [String:String]) {
        var columns: [String] = [];
        var stmt:OpaquePointer?;
        for (name, type) in specs {
            columns.append("\(name) \(type)")
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
    
    
    
    func select(from table: String, values:[String], where w:[String:Any] = [:]) -> [[String:Any]] {
        var stmt:OpaquePointer?;
        let (whereClause, whereParameters) = makeWhereClause(w);
        print("SELECT \(values.joined(separator: ",")) FROM \(table) \(whereClause)    -> \(w)")
        if sqlite3_prepare(db, "SELECT \(values.joined(separator: ",")) FROM \(table) \(whereClause)", -1, &stmt, nil) != SQLITE_OK {
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
                    row[item] = sqlite3_column_int(stmt, i);
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
    
    func insert(to table: String, values v:[String: Any]) {
        var stmt: OpaquePointer?;
        var names: [String] = [];
        var values: [Any] = [];
        for (name, value) in v {
            names.append(name);
            values.append(value);
        }
        let columnNames = names.joined(separator: ",");
        let questionMarks = Array(repeating: "?", count: names.count).joined(separator: ",");
        print("INSERT INTO \(table)(\(columnNames)) VALUES(\(questionMarks)) -> \(values)")
        if sqlite3_prepare(db, "INSERT INTO \(table)(\(columnNames)) VALUES(\(questionMarks))", -1, &stmt, nil) != SQLITE_OK {
            printLastError("insert");
            return;
        }
        bindValues(stmt, 0, values);
        if sqlite3_step(stmt) != SQLITE_DONE {
            printLastError("insert");
            return;
        }
        print("Insert into \(table)")
    }
}