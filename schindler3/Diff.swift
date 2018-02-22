//
//  Diff.swift
//  schindler3
//
//  Created by Matt Lilley on 21/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import Foundation

func changesBetween(_ left: [String], and right: [String]) -> (deletes: IndexSet, inserts: IndexSet) {
    var deletes = IndexSet();
    var inserts = IndexSet();
    var i0 = left.makeIterator();
    var i1 = right.makeIterator();
    var s0 = i0.next();
    var s1 = i1.next();
    var index0 : Int = 0;
    var index1 : Int = 0;
    while s0 != nil || s1 != nil {
        if (s0 == nil) {
            // s1 (and the rest of i1) has been added
            inserts.insert(index1)
            index1+=1;
            s1 = i1.next();
        } else if (s1 == nil) {
            // s0 (and the rest of s0) has been deleted
            deletes.insert(index0);
            index0+=1;
            s0 = i0.next();
        } else if (s0! < s1!) {
            // s0 has been deleted
            deletes.insert(index0);
            index0+=1;
            s0 = i0.next();
        } else if (s0! > s1!) {
            // s1 has been added
            inserts.insert(index1);
            index1+=1;
            s1 = i1.next();
        } else if (s0! == s1!) {
            index0+=1;
            index1+=1;
            s0 = i0.next();
            s1 = i1.next();
        }
    }
    return (deletes, inserts);
}
