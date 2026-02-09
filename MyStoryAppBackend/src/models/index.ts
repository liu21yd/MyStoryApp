export interface Slide {
  id: string;
  imageUrl: string;
  expandedImageUrl?: string;
  caption: string;
  voiceText: string;
  duration: number;
  transition: string;
  voiceUrl?: string;
}

export interface VideoConfig {
  resolution: '480p' | '720p' | '1080p' | '2k' | '4k';
  frameRate: number;
  voiceType: string;
  voiceSpeed: number;
  backgroundMusic: string;
  subtitleEnabled: boolean;
  subtitlePosition: 'top' | 'center' | 'bottom';
  aiImageExpansion: boolean;
  expansionStyle: string;
}

export interface VideoTask {
  id: string;
  title: string;
  description?: string;
  slides: Slide[];
  config: VideoConfig;
  status: 'pending' | 'expanding_images' | 'generating_voice' | 'composing' | 'completed' | 'failed';
  progress: number;
  message: string;
  outputUrl?: string;
  thumbnailUrl?: string;
  createdAt: Date;
  updatedAt: Date;
  error?: string;
}

export interface TTSPayload {
  text: string;
  voiceType: string;
  speed: number;
}

export interface ImageExpandPayload {
  imagePath: string;
  style: string;
}
