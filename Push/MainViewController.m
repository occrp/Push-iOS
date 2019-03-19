//
//  MainViewController.m
//  Push
//
//  Created by Christopher Guess on 11/11/15.
//  Copyright © 2015 OCCRP. All rights reserved.
//

#import "MainViewController.h"
#import "FeaturedArticleTableViewCell.h"
#import "ArticlePageViewController.h"
#import "ArticleViewController.h"
#import "PushSyncManager.h"
#import <SVPullToRefresh/SVPullToRefresh.h>
#import "SearchViewController.h"
#import <Masonry/Masonry.h>
#import <MBProgressHUD/MBProgressHUD.h>
#import <AFNetworking/UIImage+AFNetworking.h>
#import "LanguageManager.h"
#import "LanguagePickerView.h"
#import "AboutViewController.h"
#import "NotificationManager.h"

#import "WebSiteViewController.h"
#import "ArticleTableViewHeader.h"
#import "SectionViewController.h"
#import "LoginViewController.h"

#import "AboutBarButtonView.h"
#import "LanguageButtonView.h"

#import "AnalyticsManager.h"
#import "PromotionsManager.h"
#import "SettingsManager.h"
#import "Category.h"

// These are also set in the respective nibs, so if you change it make sure you change it there too
static NSString * featuredCellIdentifier = @"FEATURED_ARTICLE_STORY_CELL";
static NSString * standardCellIdentifier = @"ARTICLE_STORY_CELL";
static int contentWidth = 700;

@interface MainViewController ()

@property (nonatomic, retain) IBOutlet UITableView * tableView;
@property (nonatomic, retain) LanguagePickerView * languagePickerView;
@property (nonatomic, retain) UIView * languagePickerFadedBackground;
@property (nonatomic, retain) PromotionView * promotionView;

@property (nonatomic, retain) id articles;
@property (nonatomic, retain) RLMArray<Category*><Category> * categories;

@end
@implementation MainViewController

- (void)setArticles:(id)articles
{
    _articles = articles;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupNavigationBar];
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [self loadInitialArticles];
        //[MBProgressHUD hideHUDForView:self.view animated:YES];
        
    });
    
    
    
    [self loadPromotions];
    
    // TODO: Track the user action that is important for you.
    [[AnalyticsManager sharedManager] logContentViewWithName:@"Article List" contentType:nil contentId:nil customAttributes:nil];
    
    NSLog(@"%@",[RLMRealmConfiguration defaultConfiguration].fileURL);
    
    }

- (void)viewDidAppear:(BOOL)animated
{
    
    
  /*  dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [self loadInitialArticles];
        //[MBProgressHUD hideHUDForView:self.view animated:YES];
        
    });*/
    
    
    //[self loadInitialArticles];
    [self setupTableView];
    
    if([SettingsManager sharedManager].loginRequired && ![PushSyncManager sharedManager].isLoggedIn){
        [self showLoginViewController];
        return;
    }
    
    [[AnalyticsManager sharedManager] startTimerForContentViewWithObject:self name:@"Article List Timer" contentType:nil contentId:nil customAttributes:nil];
    
    
    
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[AnalyticsManager sharedManager] endTimerForContentViewWithObject:self andName:@"Article List Timer"];
}

- (void)showLoginViewController
{
    LoginViewController * loginViewController = [[LoginViewController alloc] init];
    [self.navigationController pushViewController:loginViewController animated:YES];
    return;
}

- (void)setupNavigationBar
{
    // Add Logo with custom barbutton item
    // Using a custom view for sizing
    UIImage * logoImage = [UIImage imageNamed:@"logo.png"];
    
    UIImageView * logoImageView = [[UIImageView alloc] initWithImage:logoImage];
    CGRect frame = logoImageView.frame;
    frame.size.height = self.navigationController.navigationBar.frame.size.height - 15;
    //get the appropriate width here
    CGFloat sizingRatio = frame.size.height / logoImage.size.height;
    frame.size.width = logoImage.size.width * sizingRatio;
    logoImageView.frame = frame;
    
    logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    UIBarButtonItem * occrpLogoButton = [[UIBarButtonItem alloc]
                                         initWithCustomView:logoImageView];
    
    self.navigationItem.leftBarButtonItem = occrpLogoButton;
    self.navigationController.navigationItem.leftBarButtonItem = occrpLogoButton;
    
    // Add about button
    UIBarButtonItem * aboutBarButton = [[UIBarButtonItem alloc] initWithCustomView:[[AboutBarButtonView alloc] initWithTarget:self andSelector:@selector(aboutButtonTapped)]];
    
    // Add search button
    UIBarButtonItem * searchBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonTapped)];
    
    // Add language button
    NSArray * barButtonItems = @[aboutBarButton, searchBarButton];
    if([LanguageManager sharedManager].availableLanguages.count > 1){
        LanguageButtonView * languageButtonView = [[LanguageButtonView alloc] initWithTarget:self andSelector:@selector(languageButtonTapped)];
        UIBarButtonItem * languageBarButton = [[UIBarButtonItem alloc] initWithCustomView:languageButtonView];
        barButtonItems = @[languageBarButton, aboutBarButton, searchBarButton];
    }
    
    [self.navigationItem setRightBarButtonItems:barButtonItems];
    
    // Set Back button to correct language
    [self setUpBackButton];
}

// The back button needs to be translated, which requires a new button everytime.
- (void)setUpBackButton
{
    UIBarButtonItem * backButton = [[UIBarButtonItem alloc] initWithTitle:MYLocalizedString(@"Back", @"Back") style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    
    self.navigationItem.backBarButtonItem = backButton;
}

// Just pop off the view controller
- (void)goBack
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)setupTableView
{
    self.tableView = [[UITableView alloc] init];
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
    [self.view addSubview:self.tableView];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;


    [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.tableView registerNib:[UINib nibWithNibName:@"ArticleTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:standardCellIdentifier];
    [self.tableView registerNib:[UINib nibWithNibName:@"FeaturedArticleTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:featuredCellIdentifier];
    
    __weak typeof(self) weakSelf = self;
    
    [self.tableView addPullToRefreshWithActionHandler:^{
        [[AnalyticsManager sharedManager] logCustomEventWithName:@"Pulled To Refresh Home Screen" customAttributes:nil];
        [weakSelf loadArticles];
    }];
}

- (void)viewDidLayoutSubviews {

    [super viewDidLayoutSubviews];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    while ([self.tableView dequeueReusableCellWithIdentifier:@"ArticleTableViewCell"]) {}
    while ([self.tableView dequeueReusableCellWithIdentifier:@"FeaturedArticleTableViewCell"]) {}
    [self.tableView reloadData];
}


- (void)loadInitialArticles
{
    
    RLMResults<Category *> *Categories = [[Category objectsWhere: [NSString stringWithFormat: @"language == '%@'", [LanguageManager sharedManager].languageShortCode]] sortedResultsUsingKeyPath:@"orderIndex" ascending:true];
    NSLog(@"%@", Categories);
    self.categories = Categories;
    if(self.categories.count == 0){
        
        [self loadArticles];
 
    }else{
       
           [MBProgressHUD hideHUDForView:self.view animated:YES];
            [self.tableView reloadData];
      
    }
    
}


- (void)loadArticles
{
    self.articles = [[PushSyncManager sharedManager] articlesWithCompletionHandler:^(NSString *categories) {
        //NSLog(@"%@", categories);
        //if(articles)
        
        RLMResults<Category *> *Categories = [[Category objectsWhere: [NSString stringWithFormat: @"language == '%@'", [LanguageManager sharedManager].languageShortCode]] sortedResultsUsingKeyPath:@"orderIndex" ascending:true];//@"language == [LanguageManager sharedManager].languageShortCode"];
        NSLog(@"%@", Categories);
        self.categories = Categories;
        //self.categories = articles;
        [self.tableView reloadData];
        [self.tableView.pullToRefreshView stopAnimating];
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    } failure:^(NSError *error) {
        if(error.code == 1200){
            dispatch_async(dispatch_get_main_queue(), ^{
                MBProgressHUD * hud = [MBProgressHUD HUDForView:self.view];
                hud.label.text = @"Fixing Network Issue";
                hud.detailsLabel.text = @"One moment while we attempt to fix our connection...";
                hud.progress = 0.45f;
            });
            return;
        }
        
        UIAlertController * alert = [UIAlertController alertControllerWithTitle:MYLocalizedString(@"ConnectionError", @"Connection Error") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        [self.tableView.pullToRefreshView stopAnimating];
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    } loggedOut:^{
        [self showLoginViewController];
    }];
    
    if(self.articles != nil){
        [self.tableView reloadData];
    }
}

- (void)loadPromotions
{
 
    if(self.promotionView){
        [self.promotionView removeFromSuperview];
        self.promotionView = nil;
        [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view);
            make.right.equalTo(self.view);
            make.left.equalTo(self.view);
            make.bottom.equalTo(self.view);
        }];
    }
 
    NSArray * promotions = [PromotionsManager sharedManager].currentlyRunningPromotions;
    
    if(promotions.count == 0){
        return;
    }
    
    PromotionView * promotionView = [[PromotionView alloc] initWithPromotion:promotions[0]];
    
    if(!promotionView){
        return;
    }
    
    self.promotionView = promotionView;
    
    self.promotionView.delegate = self;
    [self.view addSubview:self.promotionView];
    
    [self.promotionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view);
        make.right.equalTo(self.view);
        make.left.equalTo(self.view);
        make.height.equalTo(@50);
    }];
    
    [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.promotionView.mas_bottom);
        make.right.equalTo(self.view);
        make.left.equalTo(self.view);
        make.bottom.equalTo(self.view);
    }];
}

#pragma mark - PromotionViewDelegate
- (void)didTapOnPromotion:(nonnull Promotion*)promotion
{
    NSString * language = [LanguageManager sharedManager].languageShortCode;
    WebSiteViewController * webSiteController = [[WebSiteViewController alloc] initWithURL:[NSURL URLWithString:promotion.urls[language]]];
    [self.navigationController presentViewController:webSiteController animated:YES completion:nil];
//    [self.navigationController pushViewController:webSiteController animated:YES];
}

#pragma mark - Menu Button Handling

- (void)aboutButtonTapped
{
    [[AnalyticsManager sharedManager] logContentViewWithName:@"About Tapped" contentType:@"Navigation"
                          contentId:nil customAttributes:nil];

    AboutViewController * aboutViewController = [[AboutViewController alloc] init];
    [self.navigationController pushViewController:aboutViewController animated:YES];
}

- (void)searchButtonTapped
{
    [[AnalyticsManager sharedManager] logContentViewWithName:@"Search Tapped" contentType:@"Navigation"
                          contentId:nil customAttributes:nil];

    SearchViewController * searchViewController = [[SearchViewController alloc] init];
    [self.navigationController pushViewController:searchViewController animated:YES];
}


- (void)languageButtonTapped
{
    if(!self.languagePickerView){
        [[AnalyticsManager sharedManager] logContentViewWithName:@"Language Button Tapped and Shown" contentType:@"Settings"
                              contentId:nil customAttributes:nil];

        [self showLanguagePicker];
    } else {
        [[AnalyticsManager sharedManager] logContentViewWithName:@"Language Button Tapped and Hidden" contentType:@"Settings"
                              contentId:nil customAttributes:nil];

        [self hideLanguagePicker];
    }
}

#pragma mark Language Picker

- (void)languagePickerDidChooseLanguage:(NSString *)language
{
    [[AnalyticsManager sharedManager] logContentViewWithName:@"Language Chosen" contentType:@"Settings"
                          contentId:language customAttributes:@{@"language":language}];

    NSString * oldLanguageShortCode = [LanguageManager sharedManager].languageShortCode;
    
    [[LanguageManager sharedManager] setLanguage:language];
    
    [[NotificationManager sharedManager] changeLanguage:oldLanguageShortCode
                                                     to:[LanguageManager sharedManager].languageShortCode];
    
    [self hideLanguagePicker];
    
    //Reload the view?
    [self setUpBackButton];
    // Triggering this reloads the articles with the new language.
    
    //[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    // This handles the clearing up of the HUD properly.
    [self loadArticles];
    [self loadPromotions];
    [self.view setNeedsDisplay];
}

- (void)showLanguagePicker
{
    if(self.languagePickerView){
        return;
    }
    
    self.languagePickerFadedBackground = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    
    self.languagePickerFadedBackground.backgroundColor = [UIColor blackColor];
    self.languagePickerFadedBackground.alpha = 0.0f;
    
    UITapGestureRecognizer * tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(languagePickerBackgroundTapped:)];
    tapRecognizer.numberOfTapsRequired = 1;
    tapRecognizer.numberOfTouchesRequired = 1;
    [self.languagePickerFadedBackground addGestureRecognizer:tapRecognizer];
    
    self.languagePickerView = [[LanguagePickerView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 200.0f)];
    self.languagePickerView.delegate = self;
    
    [self.view addSubview:self.languagePickerFadedBackground];
    [self.view addSubview:self.languagePickerView];
    [UIView animateWithDuration:0.5f animations:^{
        CGRect frame = self.languagePickerView.frame;
        frame.origin.y = self.view.frame.size.height - frame.size.height;
        self.languagePickerView.frame = frame;
        
        self.languagePickerFadedBackground.alpha = 0.5;
    }];
}

- (void)hideLanguagePicker
{
    if(!self.languagePickerView){
        return;
    }
    
    [UIView animateWithDuration:0.5f animations:^{
        CGRect frame = self.languagePickerView.frame;
        frame.origin.y = self.view.frame.size.height;
        self.languagePickerView.frame = frame;
        self.languagePickerFadedBackground.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [self.languagePickerView removeFromSuperview];
        self.languagePickerView = nil;
        
        [self.languagePickerFadedBackground removeFromSuperview];
        self.languagePickerFadedBackground = nil;
    }];

}

- (void)languagePickerBackgroundTapped:(UITapGestureRecognizer*)recognizer
{
    if(recognizer.state == UIGestureRecognizerStateEnded){
        [self hideLanguagePicker];
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 100.0f;
    
    if( self.categories != nil){
        if(indexPath.row == 0){
            if(indexPath.section == 0){
                height = 42.0f;
            } else {
                height = 48.0f;
            }
        }else if(indexPath.row == 1){
            height = 434.0f;
        }
    }else if(indexPath.row == 0){
        height = 434.0f;
    }
    
    return height;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:NO];
    
    RLMArray * articles;
    
    if(self.categories != nil ){
        articles = self.categories[indexPath.section].articles;
    } else {
        articles = self.articles;
    }
    
    // If they tap on the section header
    if(indexPath.row == 0 && self.categories != nil ){
        
        ArticleTableViewHeader * cell = (ArticleTableViewHeader*)[self tableView:tableView cellForRowAtIndexPath:indexPath].backgroundView;
        SectionViewController * sectionViewController = [[SectionViewController alloc]
                                                         initWithSectionTitle:self.categories[indexPath.section].category
                                                         andArticles:self.categories[indexPath.section].articles];
        
        [self.navigationController pushViewController:sectionViewController animated:YES];
        return;
    }

    
    ArticlePageViewController * articlePageViewController = [[ArticlePageViewController alloc] initWithArticles: self.categories[indexPath.section].articles];
    
    Article * article;
    if(self.categories != nil ){
        article = self.categories[indexPath.section].articles[indexPath.row-1];
    } else{
        article = self.articles[indexPath.row];
    }
    
    ArticleViewController * articleViewController = [[ArticleViewController alloc] initWithArticle:article];
    dispatch_async(dispatch_get_main_queue(), ^{
    [articlePageViewController setViewControllers:@[articleViewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
   
    [[AnalyticsManager sharedManager] logContentViewWithName:@"Article List Item Tapped" contentType:@"Navigation"
                          contentId:article.description customAttributes:article.trackingProperties];
    
    
    [self.navigationController pushViewController:articlePageViewController animated:YES];
    });
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
 
    //[self beginBatchFatch];
    ArticleTableViewCell * cell;
    
    // If the articles are seperated by Categories it will be a dictionary here.
    if( self.categories != nil ){
        
        if(indexPath.row == 0){
            ArticleTableViewHeader * header = [[ArticleTableViewHeader alloc] initWithTop:(indexPath.section == 0)];
            header.categoryName = self.categories[indexPath.section].category;
            UITableViewCell * cell = [[UITableViewCell alloc] init];
            cell.backgroundView = header;
            return cell;
        } else {
            NSString * sectionName = self.categories[indexPath.section].category;
            RLMArray * articles = self.categories[indexPath.section].articles;
            
            if(indexPath.row == 1){
                cell = [tableView dequeueReusableCellWithIdentifier:featuredCellIdentifier];
            } else {
                cell = [tableView dequeueReusableCellWithIdentifier:standardCellIdentifier];
            }
            
            cell.article = self.categories[indexPath.section].articles[indexPath.row - 1];
        }
    } else {
        // This is the path if there are no categories
        if(indexPath.row == 0){
            cell = [tableView dequeueReusableCellWithIdentifier:featuredCellIdentifier];
        } else {
            cell = [tableView dequeueReusableCellWithIdentifier:standardCellIdentifier];
        }
        
        cell.article = self.categories[indexPath.section].articles[indexPath.row - 1];
    }

    if(self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular){
        int margin = (tableView.frame.size.width - contentWidth) / 2;
        [cell.contentView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(cell);
            make.bottom.equalTo(cell);
            make.left.equalTo(cell).offset(margin);
            make.right.equalTo(cell).offset(-margin);
            make.width.equalTo([NSNumber numberWithInteger:contentWidth]);
        }];
    } else {
        [cell.contentView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(cell);
        }];
    }
    
    [cell setNeedsDisplay];
    return cell;
}


- (void) scrollViewDidScroll:(UIScrollView *)scrollView{
    CGFloat offset = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    
    if (offset > contentHeight){
        
        [self beginBatchFatch];
    }
    
    
}

- (void) beginBatchFatch {
    
   // ArticleListTableViewController * tableViewSwift = [ArticleListTableViewController new];
    //[tableViewSwift testSwift];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    
        return [self.categories count];
  
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Random number for testing

    
    return 6; //[self.categories[section].articles count] + 1;
    
}

@end
