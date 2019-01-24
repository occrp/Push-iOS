//
//  ArticleSwift.swift
//  Push
//
//  Created by Izudin Vragic on 08/11/2018.
//  Copyright © 2018 OCCRP. All rights reserved.
//

import Foundation


class PushImageSwift: RLMObject {
    
    let length : Int?
    let height : Int?
    let width : Int?
    let start : Int?
    let caption : String?
    let byline : String?
    let url : String?
    
     init(length : Int?,height : Int?, width : Int?, start : Int?,caption : String?,byline : String?,url : String?) {
     
        self.length = length
        self.height = height
        self.width = width
        self.start = start
        self.caption = caption
        self.byline = byline
        self.url = url
    }
}

class PushVideoSwift: RLMObject {
    
    let youtubeId : String?
    
    init(youtubeId : String?) {
      super.init()
        self.youtubeId = youtubeId
    
    }
}

class ArticleSwift: RLMObject, Codable {
    
    let id : Int?
    let  headline : String?
    let  descriptionText : String?
    let  body : String?
    let  dbBodyString : String?
    let  bodyHTML : NSAttributedString?
    let headerImage : PushImageSwift?
    //let images = RLMArray<PushImageSwift>()
    /*let RLMArray<PushVideo*><PushVideo> * videos;
    let NSDate * publishDate;
    let NSString * author;
    let NSString * category;
    let ArticleLanguage language;
    let NSInteger languageInteger;
    let NSURL * linkURL;
    let NSString * linkURLString;
    let NSString * dateByline;
    let NSString * shortDateByline;
    let NSDictionary * trackingProperties;*/
    
    func encode(to encoder: Encoder) throws {
        
    }
    
    required init(from decoder: Decoder) throws {
        super.init()
    }
}
