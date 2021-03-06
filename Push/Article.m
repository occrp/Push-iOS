//
//  Article.m
//  Push
//
//  Created by Christopher Guess on 10/29/15.
//  Copyright © 2015 OCCRP. All rights reserved.
//

#import "Article.h"
#import "LanguageManager.h"
#import "SettingsManager.h"
#import <DateTools/DateTools.h>

#import "NSMutableAttributedString+HTML.h"
#import "NSString+ReverseString.h"
#import "NSURL+URLWithNonLatinString.h"

#import <AFNetworking/UIImageView+AFNetworking.h>
#import <AFNetworking/AFImageDownloader.h>

#import "Constants.h"
#import <HTMLKit/HTMLKit.h>

@implementation PushImage

- (id)initWithJSONDictionary:(NSDictionary *)jsonDictionary {
    if (self = [super init]){
        self.length = [jsonDictionary[@"length"] integerValue];
        self.height = [jsonDictionary[@"height"] integerValue];
        self.start = [jsonDictionary[@"start"] integerValue];
        self.byline = jsonDictionary[@"byline"];
        self.width = [jsonDictionary[@"width"] integerValue];
        self.caption = jsonDictionary[@"caption"];
        self.url = jsonDictionary[@"url"];
    }
    
    return self;
}
@end

@implementation PushVideo

- (id)initWithJSONDictionary:(NSDictionary *)jsonDictionary {
    if (self = [super init]){
        self.youtubeId = jsonDictionary[@"youtube_id"];
    }
    
    return self;
}

@end

@interface Article ()

@end

@implementation Article

+ (instancetype)articleFromDictionary:(NSDictionary *)jsonDictionary {
    Article * article = [[Article alloc] initWithDictionary:jsonDictionary];
    
    return article;
}

+ (instancetype)articleFromDictionary:(NSDictionary *)jsonDictionary andCategory:(NSString*)category;
{
    Article * article = [Article articleFromDictionary:jsonDictionary];
    article.category = category;
    return article;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if(self = [super init]) // this needs to be [super initWithCoder:aDecoder] if the superclass implements NSCoding
    {
        NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"%Y%m%d";

        self.id                 = [[aDecoder decodeObjectForKey:@"id"] integerValue];
        self.headline           = [aDecoder decodeObjectForKey:@"headline"];
        self.descriptionText    = [aDecoder decodeObjectForKey:@"description"];
        self.body               = [aDecoder decodeObjectForKey:@"body"];
        self.headerImage        = [aDecoder decodeObjectForKey:@"header_image"];
        
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [[aDecoder decodeObjectForKey:@"images"] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self.images addObject:[[PushImage alloc] initWithJSONDictionary:obj]];
            }] ;
        }];
        
        [realm transactionWithBlock:^{
            [[aDecoder decodeObjectForKey:@"videos"] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self.videos addObject:[[PushVideo alloc] initWithJSONDictionary:obj]];
            }] ;
        }];

        self.author             = [aDecoder decodeObjectForKey:@"author"];
        self.category           = [aDecoder decodeObjectForKey:@"category"];
        self.publishDate        = [formatter
                                   dateFromString:[aDecoder decodeObjectForKey:@"publish_date"]];
        self.linkURL            = [aDecoder decodeObjectForKey:@"linkURL"];
        
        NSString * language = [aDecoder decodeObjectForKey:@"language"];
        if([language isEqualToString:@"en-Gb"]) {
            self.language = ENGLISH;
        } else if([language isEqualToString:@"ru"]){
            self.language = RUSSIAN;
        } else if([language isEqualToString:@"az"]){
            self.language = AZERBAIJANI;
        } else if([language isEqualToString:@"ro"]){
            self.language = ROMANIAN;
        } else if([language isEqualToString:@"sr"]){
            self.language = SERBIAN;
        } else if([language isEqualToString:@"bs"]){
            self.language = BOSNIAN;
        }else if([language isEqualToString:@"ka"]){
            self.language = GEORGIAN;
        }

    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)jsonDictionary andCategory:(NSString*)category{
    self = [self initWithDictionary:jsonDictionary];
    self.category = category;
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)jsonDictionary{
    self = [super init];
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc ] init];
    formatter.dateFormat = @"yyyyMMdd";

    self.id                 = [jsonDictionary[@"id"] integerValue];
    self.headline           = jsonDictionary[@"headline"];
    self.descriptionText    = jsonDictionary[@"description"];
    self.body               = jsonDictionary[@"body"];
    self.headerImage        = jsonDictionary[@"header_image"];
    
    // Need to handle images and video without realm transaction block couse at this point they are just NSArrays
    
    
    RLMRealm *realm = [RLMRealm defaultRealm];
    NSArray * imagesArray = jsonDictionary[@"images"];
    for (NSDictionary * image in imagesArray) {
      [self.images addObject:[[PushImage alloc] initWithJSONDictionary:image]];
    }
    NSArray * videosArray = jsonDictionary[@"videos"];
    for (NSDictionary * video in videosArray) {
        [self.videos addObject:[[PushVideo alloc] initWithJSONDictionary:video]];
    }
  

    self.author             = jsonDictionary[@"author"];
    self.publishDate        = [formatter dateFromString:jsonDictionary[@"publish_date"]];
    
    // For backwards compatibility the first image in the self.images array may also be the header
    // If that's the case, we want to remove it

    if((self.images.count > 0 && self.headerImage) && [self.images[0][@"url"] isEqualToString:self.headerImage[@"url"]]) {
        [realm beginWriteTransaction];
        [self.images removeObjectAtIndex:0];
        [realm commitWriteTransaction];
    }

    NSURL * url;
    if(jsonDictionary[@"url"] != nil){
        url = [NSURL URLWithString:jsonDictionary[@"url"]];
    } else {
        url = [NSURL URLWithString:@""];
    }
    
    self.linkURL = url;
    
    
    NSString * language = jsonDictionary[@"language"];
    if([[language substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"en"]) {
        self.language = ENGLISH;
    } else if([[language substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"ru"]){
        self.language = RUSSIAN;
    } else if([[language substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"az"]){
        self.language = AZERBAIJANI;
    } else if([[language substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"ro"]){
        self.language = ROMANIAN;
    } else if([[language substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"sr"]){
        self.language = SERBIAN;
    } else if([[language substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"bs"]){
        self.language = BOSNIAN;
    } else if([[language substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"ka"]){
        self.language = GEORGIAN;
    }

    
    
    return self;
}


- (void)setBody:(NSString *)body
{
    
    _body = [self formatArticleHtml:body];
    self.dbBodyString = _body;

    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //});

}

- (NSString*)getBody {
    return self.dbBodyString;
}

- (NSAttributedString*)bodyHTML {
    NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 7.0f;
    paragraphStyle.paragraphSpacing = 5.0f;
    paragraphStyle.paragraphSpacingBefore = 5.0f;
    
    NSString * html = [self.dbBodyString stringByAppendingString:[NSString stringWithFormat:@"<style>body{font-family: '%@'; font-size:%fpx;}</style>", @"Palatino-Roman", 17.0f]];
    
    html = [html stringByReplacingOccurrencesOfString:@"</p>\n\n<p>" withString:@"</p><br /><br /><p>"];
    // For Android you need two breaks to make a proper space. On iOS that adds double blanks.
    html = [html stringByReplacingOccurrencesOfString:@"<br /><br />" withString:@"<br />\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<br><br>" withString:@"<br />\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<br><br />" withString:@"<br />\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<br /><br>" withString:@"<br />\n"];
    
    html = [html stringByReplacingOccurrencesOfString:@"<h1>" withString:@"<br /><br /><h1>"];
    html = [html stringByReplacingOccurrencesOfString:@"<\\h1>" withString:@"<\\h1>\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<h2>" withString:@"<br /><br /><h2>"];
    html = [html stringByReplacingOccurrencesOfString:@"<\\h2>" withString:@"<\\h2>\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<h3>" withString:@"<br /><br /><h3>"];
    html = [html stringByReplacingOccurrencesOfString:@"<\\h3>" withString:@"<\\h3>\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<h4>" withString:@"<br /><br /><h4>"];
    html = [html stringByReplacingOccurrencesOfString:@"<\\h4>" withString:@"<\\h4>\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<h5>" withString:@"<br /><br /><h5>"];
    html = [html stringByReplacingOccurrencesOfString:@"<\\h5>" withString:@"<\\h5>\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<h6>" withString:@"<br /><br /><h6>"];
    html = [html stringByReplacingOccurrencesOfString:@"<\\h6>" withString:@"<\\h6>\n"];
    
    html = [self addGravestonesForImages:html];
    html = [html stringByReplacingOccurrencesOfString:@"<br />\n</p><br />\n<p></p><br>" withString:@"</p><br />\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<br>\n</p><br>\n<p></p><br>" withString:@"</p><br />\n"];
    html = [html stringByReplacingOccurrencesOfString:@"<br>\n<p></p><br>" withString:@"<br />\n"];
    
    
    NSMutableAttributedString * bodyAttributedText = [[NSMutableAttributedString alloc]
                                                      initWithHTML:[html dataUsingEncoding:NSUTF8StringEncoding]
                                                      baseURL:[SettingsManager sharedManager].cmsBaseUrl
                                                      documentAttributes:nil];
    
    [bodyAttributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, bodyAttributedText.string.length)];
    
    
    return [self addImagePlaceholderToAttributedString:bodyAttributedText];

}

- (NSString*)addGravestonesForImages:(NSString*)html
{
    NSArray * imageLocations = [self imageLocationsInText:html];
    
    // Reversed so that as we change stuff it doesn't mess with the numbering
    imageLocations = [[imageLocations reverseObjectEnumerator] allObjects];
    
    NSString * imageGravestoneMarker = kImageGravestone;
    NSMutableString * mutableHtml = [NSMutableString stringWithString:html];
    for(NSValue * rangeValue in imageLocations) {
        NSRange range = [rangeValue rangeValue];
        if(!self.headerImage && rangeValue == imageLocations.lastObject){
            [mutableHtml replaceCharactersInRange:range withString:@""];
            continue;
        }
        
        [mutableHtml insertString:imageGravestoneMarker atIndex:range.location];
        [mutableHtml insertString:@"<br />" atIndex:range.location];
        
        NSUInteger imageIndex = [imageLocations indexOfObject:rangeValue];
        if(!self.headerImage){
            imageIndex++;
        }
        
        NSString * caption = self.images[imageIndex][@"caption"];
        caption = [NSString stringWithFormat:@" <br><small>%@</small>", caption];
        [mutableHtml insertString:caption atIndex:range.location + kImageGravestone.length + 6];
        
    }
    html = [NSString stringWithString:mutableHtml];
    
    HTMLDocument *document = [HTMLDocument documentWithString: html];
    NSArray * images = [document querySelectorAll:@"img"];
    for(HTMLElement * imageElement in images){
        [imageElement.parentNode removeChildNode:imageElement];
    }
    
    return document.innerHTML;
}

// Wrote this without test from memory. There's a 10% chance it works
- (NSArray*)imageLocationsInText:(NSString*)text
{
    // Find all strings push=":::"
    // Find the nearest < before the location
    // Unless it's at the start of the string, in which case do the one afterwards
    // return an array of the new line location
    
    NSString * compareRange = @"push=\":::\"";
    
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:compareRange options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray<NSTextCheckingResult*> * ranges = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    
    // Here we scan backwards in a string until we find the '<'
    
    NSMutableArray * correctedRanges = [NSMutableArray arrayWithCapacity:ranges.count];
    
    for(NSTextCheckingResult * checkingResult in ranges) {
        /*if(checkingResult == ranges[0]){
         continue;
         }*/
        
        for(NSUInteger pointer = checkingResult.range.location; pointer > 0; pointer--){
            char character = [text characterAtIndex:pointer];
            if(strncmp(&character, "<", 1) == 0){
                NSValue * range = [NSValue valueWithRange:NSMakeRange(pointer, 0)];
                [correctedRanges addObject:range];
                break;
            }
        }
    }
    
    return correctedRanges;
}

- (NSAttributedString*)addImagePlaceholderToAttributedString:(NSAttributedString*)attributedString
{
    NSMutableAttributedString * mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];
    NSError * error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:kImageGravestone options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray * imageGravestones = [regex matchesInString:attributedString.string options:0 range:NSMakeRange(0, attributedString.string.length)];
    
    // Reversed so that as we change stuff it doesn't mess with the numbering
    // Wow, this is a mess, please pretty please comment me
    
    // Let's try commenting this...
    // We start at the end so that as we change we don't have to take into account how stuff changed up stream
    imageGravestones = [[imageGravestones reverseObjectEnumerator] allObjects];
    
    // If the headerImage is start start at 0, if isn't start at 1
    
    int index = 1;
    
    if(self.headerImage){
        index = 0;
    }

    // Go through each of the results
    for(NSTextCheckingResult * checkingResult in imageGravestones){
        NSRange range = checkingResult.range;
        
        NSTextAttachment * imageAttachment = [[NSTextAttachment alloc] init];
        imageAttachment.image = [UIImage imageNamed:@"launch-screen-logo@3x.png"];
        imageAttachment.bounds = CGRectMake(imageAttachment.bounds.origin.x, imageAttachment.bounds.origin.y, [UIScreen mainScreen].bounds.size.width, imageAttachment.bounds.size.height);
        
        NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:imageAttachment];
        [mutableAttributedString replaceCharactersInRange:range withAttributedString:attrStringWithImage];
        
        index++;
    }
    
    // If the headerImage is start start at 0, if isn't start at 1
    // I was dumb before, this is now the right way to do it.
    index = 1;
    
    if(self.headerImage){
        index = 0;
    }

    for(NSTextCheckingResult * checkingResult in imageGravestones){
        if(index < self.images.count){
            NSString * url = self.images[index][@"url"];

            [self loadImage:url intoAttributedText:mutableAttributedString];
            
            index++;
        } else {
            break;
        }
    }
    
    NSAttributedString * newAttributedString = [[NSAttributedString alloc] initWithAttributedString:mutableAttributedString];
    return newAttributedString;
}



- (void)loadImage:(NSString*)url intoAttributedText:(NSAttributedString*)attributedText
{
    NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL URLWithNonLatinString:url]
                                              cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                          timeoutInterval:60];
    
    [[AFImageDownloader defaultInstance] downloadImageForURLRequest:request success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull responseObject) {
        NSTextAttachment * imageAttachment = [[NSTextAttachment alloc] init];
        imageAttachment.image = responseObject;
        
        int indexOfImage = 0;
        
        for(NSDictionary * imageDictionary in self.images){
            /*if(imageDictionary == self.article.images[0]){
             continue;
             }*/
            
            NSString * escapedUrlString = [imageDictionary[@"url"] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
            if([escapedUrlString isEqualToString:request.URL.absoluteString]){
                break;
            }
            
            indexOfImage++;
        }
        
        __block int indexOfAttribute = 1;
        // If the headerImage is start start at 0, if isn't start at 1
        if(self.headerImage){
            indexOfAttribute = 0;
        }

        // Going through every attribute in the text, including bolds etc.
        [attributedText enumerateAttribute:NSAttachmentAttributeName
                                             inRange:NSMakeRange(0, [attributedText length])
                                             options:NSAttributedStringEnumerationReverse
                                          usingBlock:^(id value, NSRange range, BOOL *stop)
         {
             if ([value isKindOfClass:[NSTextAttachment class]]) {
                 // If the element is in the right range of the element we just loaded
                 if(indexOfImage == indexOfAttribute){
                     // Do a cast
                     NSTextAttachment *attachment = (NSTextAttachment *)value;
                     
                     // If the attachment has an image
                     if ([attachment image]){
                         // We should use intrinsic here, but if you're flipping fast it doesn't work for some reason
                         // float scale = self.body.intrinsicContentSize.width / responseObject.size.width;
                         float scale = ([UIScreen mainScreen].bounds.size.width) / responseObject.size.width;
                         
                         attachment.bounds = CGRectMake(attachment.bounds.origin.x, attachment.bounds.origin.y, [UIScreen mainScreen].bounds.size.width, responseObject.size.height * scale);
                         
                         /*dispatch_async(dispatch_get_main_queue(), ^{
                             [self.body setNeedsLayout];
                             [self.body.layoutManager invalidateDisplayForCharacterRange:NSMakeRange(0, self.body.attributedText.length)];
                         });
                         */
                         
                         // Set the image to object that we've responded to
                         attachment.image = responseObject;

                         // Set the body test
                         _bodyHTML = attributedText;
                         *stop = YES;
                     }
                 }
                 indexOfAttribute++;
             }
         }];
        
    } failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
        NSLog(@"Error: %@", error.localizedDescription);
    }];
    
}


- (void)preloadImage:(NSString*)url
{
    NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL URLWithNonLatinString:url]
                                              cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                          timeoutInterval:60];
    
    [[AFImageDownloader defaultInstance] downloadImageForURLRequest:request success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull responseObject) {
        
    // Don't do anything here, AFNetworking should handle the cahching automatically.
        
    } failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
        NSLog(@"Error: %@", error.localizedDescription);
    }];

}

//
- (void)setHeaderImage:(NSDictionary *)headerImage
{
    if(!headerImage){
        return;
    }
 
    _headerImage = headerImage;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self preloadImage:headerImage[@"url"]];
    });
}

- (void)setImages:(RLMArray<PushImage*><PushImage> *)images
{
    _images = images;
    
    for(NSDictionary * image in images){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self preloadImage:image[@"url"]];
        });
    }
}

- (void)setLanguage:(ArticleLanguage)language
{
    self.languageInteger = language;
}

- (ArticleLanguage)getLanguage {
    return self.languageInteger;
}

- (void)setLinkURL:(NSURL *)linkURL {
    self.linkURLString = linkURL.absoluteString;
}

- (NSURL*)linkURL {
    return [NSURL URLWithString:self.linkURLString];
}

- (NSString*)formatArticleHtml:(NSString*)html
{
    
    HTMLParser *parser = [[HTMLParser alloc] initWithString:html];
    HTMLDocument *document = [parser parseDocument];
    
    HTMLElement * element = document.body;
    
    NSMutableArray * paragraphNodes = [NSMutableArray array];
    NSMutableArray * breakNodes = [NSMutableArray array];
    
    [element enumerateChildElementsUsingBlock:^(HTMLElement *element, NSUInteger idx, BOOL *stop) {
        if ([element.tagName isEqualToString:@"p"]) {
            if(element.nextSibling){
                [paragraphNodes addObject:element];
            }
        } else if([element.tagName isEqualToString:@"br"]){
            [breakNodes addObject:element];
        }
    }];
    
    for(HTMLElement * element in paragraphNodes){
        HTMLElement * breakTag = [[HTMLElement alloc] initWithTagName:@"br"];

        [element.parentNode insertNode:breakTag beforeChildNode:element.nextSibling];
    }
    
    for(HTMLElement * element in breakNodes){
        if(element.nextSibling.nodeType != element.nodeType){
            HTMLElement * breakTag = [[HTMLElement alloc] initWithTagName:@"br"];

            [element.parentNode insertNode:breakTag beforeChildNode:element];
        }
    }
    
    return document.body.innerHTML;
}


- (NSString*)dateByline
{
    NSDateFormatter * formatter = [self formatterForDate:NSDateFormatterLongStyle];
    NSString * dateString = [formatter stringFromDate:self.publishDate];
    return [self dateBylineForDateString:dateString];
}

- (NSString*)shortDateByline
{
    NSString * dateString;
    if(self.publishDate.daysAgo > 1 || ![[LanguageManager sharedManager] dateShouldBeColloquial]){
        NSDateFormatter * formatter = [self formatterForDate:NSDateFormatterShortStyle];
        dateString = [formatter stringFromDate:self.publishDate];
    } else {
        dateString = [[LanguageManager sharedManager] localizedRelativeDate:self.publishDate.timeAgoSinceNow];
    }
    
    return [self dateBylineForDateString:dateString];
}

- (NSString*)dateBylineForDateString:(NSString*)dateString
{
    NSString * dateBylineText;
    if([SettingsManager sharedManager].shouldShowAuthor && self.author.class != [NSNull class] && self.author.length > 0){
        NSString * format = [[LanguageManager sharedManager] bylineFormatForLanguageShortCode:[LanguageManager sharedManager].languageShortCode];
        dateBylineText = [NSString stringWithFormat:format, dateString, self.author];
    } else {
        dateBylineText = dateString;
    }
    
    return dateBylineText;
}

- (NSDateFormatter*)formatterForDate:(NSDateFormatterStyle)formatterStyle
{
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterNoStyle;
    formatter.dateStyle = formatterStyle;
    
    NSString * localeID = [LanguageManager sharedManager].languageShortCode;
    if([localeID isEqualToString:@"sr"]){
        localeID = @"sr_Latn";
    }
    
    formatter.locale = [NSLocale localeWithLocaleIdentifier:localeID];
    
    return formatter;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    NSDateFormatter * formatter = [[NSDateFormatter alloc ] init];
    formatter.dateFormat = @"%Y%m%d";
    
    [encoder encodeObject:[NSNumber numberWithInt:self.id] forKey:@"id"];
    [encoder encodeObject:self.headline forKey:@"headline"];
    [encoder encodeObject:self.descriptionText forKey:@"description"];
    [encoder encodeObject:self.body forKey:@"body"];
    //[encoder encodeObject:self.headerImage forKey:@"header_image"];
    
  /*  RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        /*[[aDecoder decodeObjectForKey:@"images"] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self.images addObject:[[PushImage alloc] initWithJSONDictionary:obj]];
        }] ;
        
       [encoder encodeObject:self.images forKey:@"images"];
        
        
        
    }];
    
    [realm transactionWithBlock:^{
       [encoder encodeObject:self.videos forKey:@"videos"];
    }]; */
    
    
    //[encoder encodeObject:self.images forKey:@"images"];
    //[encoder encodeObject:self.videos forKey:@"videos"];
    //PushImage image1 = [PushImage ]
    
    [encoder encodeObject:self.author forKey:@"author"];
    [encoder encodeObject:self.category forKey:@"category"];
    [encoder encodeObject:[formatter stringFromDate:self.publishDate] forKey:@"publish_date"];
    [encoder encodeObject:self.linkURL forKey:@"linkURL"];
    
    NSString * languageKey = @"language";
    switch (self.language) {
        case ENGLISH:
            [encoder encodeObject:@"en-GB" forKey:languageKey];
            break;
        case RUSSIAN:
            [encoder encodeObject:@"ru" forKey:languageKey];
        case AZERBAIJANI:
            [encoder encodeObject:@"az" forKey:languageKey];
        case ROMANIAN:
            [encoder encodeObject:@"ro" forKey:languageKey];
        default:
            break;
    }
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ - %@", self.headline, self.linkURL.absoluteString];
}

/**
 *  Used for tracking article in Crashalytics
 *
 *  @return a dictionary of properties representing this article for Crashalytics tracking
 */
- (NSDictionary*)trackingProperties
{
    return @{@"Article Headline":self.headline,
             @"Article Url":self.linkURL.absoluteString,
             @"Article Description":self.description};
}

+ (NSArray *)ignoredProperties {
    return @[@"language", @"linkURL", @"bodyHTML", @"body"];
}

+ (NSString *)primaryKey {
    return @"id";
}


@end
