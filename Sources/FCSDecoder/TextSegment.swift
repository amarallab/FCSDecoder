//
//  TextSegment.swift
//  FCSDecoder
//
//  Created by Helio Tejedor on 7/15/21.
//

import Foundation

struct InternalChannel: Decodable, Equatable, Hashable {
    var b: Int
    var e: Amplification
    var n: String
    var r: Double // TODO: depends on the datatype
    
    var calibration: String?
    var d: SuggestedVisualization?
    var f: String?
    var g: Float?
    var l: ExcitationWaveLengths?
    var o: Int?
    var p: Int?
    var s: String?
    var t: String?
    var v: Float?
    
    enum CodingKeys: String, CodingKey {
        case b = "B",
             e = "E",
             n = "N",
             r = "R",
             calibration = "CALIBRATION",
             d = "D",
             f = "F",
             g = "G",
             l = "L",
             o = "O",
             p = "P",
             s = "S",
             t = "T",
             v = "V"
    }
}

extension InternalChannel: Parametrized {
    static var paramCountKey: String? = "$PAR"
    static var paramPrefixes: [String] = ["$P", "P"]
}

struct Flag: Decodable, Equatable, Hashable {
    var value: Int
    
    enum CodingKeys: String, CodingKey {
        case value = "FLAG"
    }
}

extension Flag: Parametrized {
    static var paramCountKey: String? = "$CSMODE"
    static var paramPrefixes: [String] = ["$CSV"]
}

struct Gate: Decodable, Equatable, Hashable {
    var e: Amplification
    var f: String
    var n: String
    var p: Int
    var r: Int
    var s: String
    var t: String
    var v: Int
}

extension Gate: Parametrized {
    static var paramCountKey: String? = "$GATE"
    static var paramPrefixes: [String] = ["$G"]
}

struct Region: Decodable, Equatable, Hashable {
    var i: [String]
    var w: [Float]
    
    enum CodingKeys: String, CodingKey {
        case i = "I"
        case w = "W"
    }
}

extension Region: Parametrized {
    static var paramCountKey: String? = nil
    static var paramPrefixes: [String] = ["$R"]
}

struct TextSegment: Decodable, Hashable, Equatable {
    var beginAnalysis: Int
    var endAnalysis: Int
    var beginData: Int
    var endData: Int
    var beginSText: Int
    var endSText: Int
    var byteOrd: ByteOrder
    var dataType: DataType
    var mode: Mode
    var nextData: Int
    var tot: Int
    
    var channels: [InternalChannel]
    
    var abrt: Int?
    var bTim: FCSDecoder.Time?
    var cells: String?
    var com: String?
    var csMode: Int?
    var csvBits: Int?
    var csvFlags: [Flag]?
    var cyt: String?
    var cytSN: String?
    var date: FCSDecoder.Date?
    var etim: FCSDecoder.Time?
    var exp: String?
    var fil: String?

    var gates: [Gate]?
    var gating: String?
    
    var inst: String?
    var lastModified: FCSDecoder.FullDate?
    var lastModifier: String?
    var lost: Int?
    var op: String?
    var originality: Originality?
    var plateId: String?
    var plateName: String?
    var proj: String?
    var regions: [Region]?
    var smno: String?
    
    enum CodingKeys: String, CodingKey {
        case beginAnalysis = "$BEGINANALYSIS",
             endAnalysis = "$ENDANALYSIS",
             beginData = "$BEGINDATA",
             endData = "$ENDDATA",
             beginSText = "$BEGINSTEXT",
             endSText = "$ENDSTEXT",
             byteOrd = "$BYTEORD",
             dataType = "$DATATYPE",
             mode = "$MODE",
             nextData = "$NEXTDATA",
             tot = "$TOT",
             
             channels = "$P---",

             abrt = "$ABRT",
             bTim = "$BTIM",
             cells = "$CELLS",
             com = "$COM",
             csMode = "$CSMODE",
             csvBits = "$CSVBITS",
             csvFlags = "$CSV---",
             cyt = "$CYT",
             cytSN = "$CYTSN",
             date = "$DATE",
             etim = "$ETIM",
             exp = "$EXP",
             fil = "$FIL",
             gates = "$G---",
             gating = "$GATING",
             
             inst = "$INST",
             lastModified = "$LAST_MODIFIED",
             lastModifier = "$LAST_MODIFIER",
             lost = "$LOST",
             op = "$OP",
             originality = "$ORIGINALITY",
             plateId = "$PLATEID",
             plateName = "$PLATENAME",
             proj = "$PROJ",
             regions = "$R---",
             smno = "$SMNO"
    }
}

