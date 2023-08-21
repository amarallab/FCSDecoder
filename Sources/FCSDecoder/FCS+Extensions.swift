//
//  FCS+Extensions.swift
//  
//
//  Created by Heliodoro Tejedor Navarro on 21/8/23.
//

import Foundation

extension FCS {
    public func findDefaultTimeChannel() -> Channel? {
        for current in channels where current.n.caseInsensitiveCompare("time") == .orderedSame {
            return current
        }
        return nil
    }
    
    public func findChannel(named: String) -> Channel? {
        for current in channels where current.n.caseInsensitiveCompare(named) == .orderedSame {
            return current
        }
        return nil
    }
}
