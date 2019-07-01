//
//  NSObject+Category.m
//  Push
//
//  Created by Izudin Vragic on 10/09/2018.
//  Copyright © 2018 OCCRP. All rights reserved.
//

#import "Category.h"


@interface Category ()

@end

@implementation Category


+ (NSString *)primaryKey {
    return @"category";
}

+ (instancetype)categoryFromArray:(RLMArray *)array andCategory:(NSString*)categoryName andLanguage:(NSString*)lng andOrderIndex:(NSString*)orderIndex{
    Category * category = [[Category alloc] initWithArray:array andCategory:(NSString*)categoryName andLanguage:(NSString*)lng andOrderIndex:(NSString*)orderIndex];
    
    return category;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if(self = [super init]) // this needs to be [super initWithCoder:aDecoder] if the superclass implements NSCoding
    {
        NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"%Y%m%d";
        
       
        
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [[aDecoder decodeObjectForKey:@"articles"] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self.articles addObject:[[Article alloc] initWithDictionary:[aDecoder decodeObjectForKey:@"articles"] andCategory:[aDecoder decodeObjectForKey:@"category"]]];
            }] ;
        }];
        
       
        self.category = [aDecoder decodeObjectForKey:@"category"];
      
 
    }
    return self;
}

- (instancetype)initWithArray:(RLMArray *)array andCategory:(NSString*)categoryName andLanguage:(NSString*)lng andOrderIndex:(NSString*)orderIndex{
    self = [super init];

    self.language = lng;
    self.category = categoryName;
    self.articles = array;
    self.orderIndex = orderIndex;
    
    return self;
    }



@end
