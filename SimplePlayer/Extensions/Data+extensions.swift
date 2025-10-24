//
//  Data+extensions.swift
//  SimplePlayer
//
//  Created by Lee Newman on 10/22/25.
//

import Foundation

extension Data {
    public var bytes: [UInt8]
    {
        return [UInt8](self)
    }
}
