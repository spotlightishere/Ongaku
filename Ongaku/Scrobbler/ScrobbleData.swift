//
//  ScrobbleData.swift
//  Ongaku
//
//  Created by Kot on 8/16/23.
//  Copyright © 2023 Spotlight Deveaux. All rights reserved.
//

import Foundation

struct ScrobbleData: Codable, Equatable {
	let artist: String
	let track: String
	let album: String?
	let duration: Int?
}
