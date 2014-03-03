//
//  ViewController.m
//  SampleCustomControls
//
// Copyright (c) 2014 Brightcove, Inc. All rights reserved.
// License: https://accounts.brightcove.com/en/terms-and-conditions
//

#import "ViewController.h"

#import "RACEXTScope.h"


// ** Customize Here **
static NSString * const kViewControllerCatalogToken = @"nFCuXstvl910WWpPnCeFlDTNrpXA5mXOO9GPkuTCoLKRyYpPF1ikig..";
static NSString * const kViewControllerPlaylistID = @"2149006311001";


@interface ViewController ()

@property (nonatomic, strong) BCOVCatalogService *catalogService;
@property (nonatomic, strong) id<BCOVPlaybackController> playbackController;
@property (nonatomic, weak) AVPlayer *currentPlayer;

@property (nonatomic, weak) IBOutlet UIView *videoViewContainer;
@property (nonatomic, weak) IBOutlet UILabel *durationLabel;
@property (nonatomic, weak) IBOutlet UILabel *elapsedTimeLabel;
@property (nonatomic, weak) IBOutlet UIButton *playPauseButton;
@property (nonatomic, weak) IBOutlet UISlider *progressSlider;
@property (nonatomic, assign) BOOL wasPlayingOnSeek;

@end


@implementation ViewController

- (id)init
{
    self = [super init];
    if (self)
	{
        [self configure];
    }
    return self;
}

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
	{
        [self configure];
    }
    return self;
}

-(void)awakeFromNib
{
    [super awakeFromNib];
    [self configure];
}

-(void)configure
{
    self.wasPlayingOnSeek = NO;
    
    BCOVPlayerSDKManager *playbackManager = [BCOVPlayerSDKManager sharedManager];
    
    id<BCOVPlaybackController> playbackController = [playbackManager createPlaybackController];
    playbackController.delegate = self;
    self.playbackController = playbackController;
    
    self.catalogService = [[BCOVCatalogService alloc] initWithToken:kViewControllerCatalogToken];
    [self requestContentFromCatalog];
}

- (void)requestContentFromCatalog
{
    @weakify(self);
    [self.catalogService findPlaylistWithPlaylistID:kViewControllerPlaylistID parameters:nil completion:^(BCOVPlaylist *playlist, NSDictionary *jsonResponse, NSError *error) {
        
        @strongify(self);
        
        if (playlist)
        {
            [self.playbackController setVideos:playlist.videos];
        }
        else
        {
            NSLog(@"ViewController Debug - Error retrieving playlist: %@", error);
        }
        
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.playbackController.view.frame = self.videoViewContainer.bounds;
    self.playbackController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.videoViewContainer addSubview:self.playbackController.view];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark BCOVPlaybackControllerDelegate

- (void)playbackController:(id<BCOVPlaybackController>)controller didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session
{
    self.currentPlayer = session.player;
    self.wasPlayingOnSeek = NO;
    
    self.elapsedTimeLabel.text = [ViewController formatTime:0];
    self.progressSlider.value = 0.f;
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didChangeDuration:(NSTimeInterval)duration
{
    self.durationLabel.text = [ViewController formatTime:duration];
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didProgressTo:(NSTimeInterval)progress
{
    self.elapsedTimeLabel.text = [ViewController formatTime:progress];
    
    NSTimeInterval duration = CMTimeGetSeconds(session.player.currentItem.duration);
    float percent = progress / duration;
    self.progressSlider.value = isnan(percent) ? 0.0f : percent;
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent
{
    if ([kBCOVPlaybackSessionLifecycleEventPlay isEqualToString:lifecycleEvent.eventType])
    {
        self.playPauseButton.selected = YES;
    }
    else if([kBCOVPlaybackSessionLifecycleEventPause isEqualToString:lifecycleEvent.eventType])
    {
        self.playPauseButton.selected = NO;
    }
}

#pragma mark IBActions

- (IBAction)playPauseButtonPressed:(UIButton *)sender
{
    if (sender.selected)
    {
        [self.currentPlayer pause];
    }
    else
    {
        [self.currentPlayer play];
    }
}

- (IBAction)sliderValueChanged:(UISlider *)sender
{
    NSTimeInterval newCurrentTime = sender.value * CMTimeGetSeconds(self.currentPlayer.currentItem.duration);
    self.elapsedTimeLabel.text = [ViewController formatTime:newCurrentTime];
}

- (IBAction)sliderTouchBegin:(UISlider *)sender
{
    self.wasPlayingOnSeek = self.playPauseButton.selected;
    [self.currentPlayer pause];
}

- (IBAction)sliderTouchEnd:(UISlider *)sender
{
    NSTimeInterval newCurrentTime = sender.value * CMTimeGetSeconds(self.currentPlayer.currentItem.duration);
    CMTime seekToTime = CMTimeMakeWithSeconds(newCurrentTime, 600);

    @weakify(self);
    
    [self.currentPlayer seekToTime:seekToTime completionHandler:^(BOOL finished) {
        
        @strongify(self);
        
        if (finished && self.wasPlayingOnSeek)
        {
            self.wasPlayingOnSeek = NO;
            [self.currentPlayer play];
        }
        
    }];
}

#pragma mark Class Methods

+ (NSString *)formatTime:(NSTimeInterval)timeInterval
{
    if (timeInterval == 0)
    {
        return @"00:00";
    }
    
    NSInteger hours = floor(timeInterval / 60.0f / 60.0f);
    NSInteger minutes = (NSInteger)(timeInterval / 60.0f) % 60;
    NSInteger seconds = (NSInteger)timeInterval % 60;
    
    NSString *ret = nil;
    if (hours > 0)
    {
        ret = [NSString stringWithFormat:@"%ld:%.2ld:%.2ld", (long)hours, (long)minutes, (long)seconds];
    }
    else
    {
        ret = [NSString stringWithFormat:@"%.2ld:%.2ld", (long)minutes, (long)seconds];
    }
    
    return ret;
}

@end
