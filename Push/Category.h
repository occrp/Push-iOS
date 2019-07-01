#import <Foundation/Foundation.h>
#import <Realm/Realm.h>
#import "Article.h"




@interface Category : RLMObject <NSCoding>


@property (nonatomic, retain) NSString * category;
@property (nonatomic, nullable) NSString * language;
@property (nonatomic, readwrite) RLMArray<Article> * articles;
@property (nonatomic, retain) NSString * orderIndex;



+ (instancetype)categoryFromArray:(RLMArray *)array  andCategory:(NSString*)categoryName andLanguage:(NSString*)lng andOrderIndex:(NSString*)orderIndex;
- (instancetype)initWithArray:(RLMArray *)array andCategory:(NSString*)categoryName andLanguage:(NSString*)lng andOrderIndex:(NSString*)orderIndex;


@end
RLM_ARRAY_TYPE(Category)

