//
//  TextSegment.swift
//  FCSDecoder
//
//  Created by Helio Tejedor on 7/15/21.
//

import Foundation

public struct Channel: Decodable {
    public var b: Int
    public var e: Amplification
    public var n: String
    public var r: Int
    
    public var calibration: String?
    public var d: SuggestedVisualization?
    public var f: String?
    public var g: Float?
    public var l: ExcitationWaveLengths?
    public var o: Int?
    public var p: Int?
    public var s: String?
    public var t: String?
    public var v: Float?
    
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

extension Channel: Parametrized {
    public static var paramCountKey: String? = "$PAR"
    public static var paramPrefixes: [String] = ["$P", "P"]
}

public struct Flag: Decodable {
    public var value: Int
    
    enum CodingKeys: String, CodingKey {
        case value = "FLAG"
    }
}

extension Flag: Parametrized {
    public static var paramCountKey: String? = "$CSMODE"
    public static var paramPrefixes: [String] = ["$CSV"]
}

public struct Gate: Decodable {
    public var e: Amplification
    public var f: String
    public var n: String
    public var p: Int
    public var r: Int
    public var s: String
    public var t: String
    public var v: Int
}

extension Gate: Parametrized {
    public static var paramCountKey: String? = "$GATE"
    public static var paramPrefixes: [String] = ["$G"]
}

public struct Region: Decodable {
    public var i: [String]
    public var w: [Float]
    
    enum CodingKeys: String, CodingKey {
        case i = "I"
        case w = "W"
    }
}

extension Region: Parametrized {
    public static var paramCountKey: String? = nil
    public static var paramPrefixes: [String] = ["$R"]
}

public struct TextSegment: Decodable {
    public var beginAnalysis: Int
    public var endAnalysis: Int
    public var beginData: Int
    public var endData: Int
    public var beginSText: Int
    public var endSText: Int
    public var byteOrd: ByteOrder
    public var dataType: DataType
    public var mode: Mode
    public var nextData: Int
    public var tot: Int
    
    public var channels: [Channel]
    
    public var abrt: Int?
    public var bTim: fcsdecoder.Time?
    public var cells: String?
    public var com: String?
    public var csMode: Int?
    public var csvBits: Int?
    public var csvFlags: [Flag]?
    public var cyt: String?
    public var cytSN: String?
    public var date: fcsdecoder.Date?
    public var etim: fcsdecoder.Time?
    public var exp: String?
    public var fil: String?

    public var gates: [Gate]?
    public var gating: String?
    
    public var inst: String?
    public var lastModified: fcsdecoder.FullDate?
    public var lastModifier: String?
    public var lost: Int?
    public var op: String?
    public var originality: Originality?
    public var plateId: String?
    public var plateName: String?
    public var proj: String?
    public var regions: [Region]?
    public var smno: String?
    
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

