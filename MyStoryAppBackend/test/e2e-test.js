#!/usr/bin/env node

/**
 * MyStoryApp 端到端测试脚本
 * 测试后端所有 API 接口
 */

const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');
const path = require('path');

const BASE_URL = process.env.API_URL || 'http://localhost:3000/api/v1';

console.log('🧪 MyStoryApp 端到端测试');
console.log(`🌐 API 地址: ${BASE_URL}\n`);

// 测试结果
const results = {
  passed: 0,
  failed: 0,
  tests: []
};

function logTest(name, success, message = '') {
  const icon = success ? '✅' : '❌';
  const status = success ? 'PASS' : 'FAIL';
  console.log(`${icon} [${status}] ${name}`);
  if (message) console.log(`   ${message}`);
  
  results.tests.push({ name, success, message });
  if (success) results.passed++;
  else results.failed++;
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// 1. 测试健康检查
async function testHealth() {
  try {
    const response = await axios.get(`${BASE_URL.replace('/api/v1', '')}/health`);
    if (response.data.status === 'ok') {
      logTest('健康检查', true, `版本: ${response.data.version}`);
      return true;
    }
  } catch (error) {
    logTest('健康检查', false, error.message);
    return false;
  }
}

// 2. 测试语音列表
async function testVoiceList() {
  try {
    const response = await axios.get(`${BASE_URL}/tts/voices`);
    if (response.data.success && Array.isArray(response.data.data)) {
      const voices = response.data.data;
      logTest('获取语音列表', true, `找到 ${voices.length} 个语音角色`);
      console.log('   可用语音:', voices.map(v => v.name).join(', '));
      return true;
    }
  } catch (error) {
    logTest('获取语音列表', false, error.message);
    return false;
  }
}

// 3. 测试语音合成
async function testTTS() {
  try {
    console.log('\n🎤 测试语音合成 (TTS)...');
    const response = await axios.post(`${BASE_URL}/tts/generate`, {
      text: '欢迎使用我的故事应用，这是百炼语音合成测试。',
      voiceType: 'standardFemale',
      speed: 1.0
    });
    
    if (response.data.success && response.data.data.audioUrl) {
      logTest('语音合成', true, `音频地址: ${response.data.data.audioUrl}`);
      return response.data.data.audioUrl;
    }
  } catch (error) {
    logTest('语音合成', false, error.response?.data?.error?.message || error.message);
    return null;
  }
}

// 4. 测试图片扩展
async function testImageExpansion() {
  try {
    console.log('\n🖼️  测试图片扩展...');
    
    // 创建一个测试图片（如果不存在）
    const testImagePath = path.join(__dirname, 'test-image.jpg');
    
    if (!fs.existsSync(testImagePath)) {
      console.log('   ⚠️  未找到测试图片，跳过图片扩展测试');
      console.log('   💡 请在 backend 目录放置一张 test-image.jpg');
      return null;
    }
    
    const form = new FormData();
    form.append('image', fs.createReadStream(testImagePath));
    form.append('style', 'cinematic');
    
    const response = await axios.post(`${BASE_URL}/image/expand`, form, {
      headers: form.getHeaders()
    });
    
    if (response.data.success && response.data.data.expandedImageUrl) {
      logTest('图片扩展', true, `扩展后图片: ${response.data.data.expandedImageUrl}`);
      return response.data.data.expandedImageUrl;
    }
  } catch (error) {
    logTest('图片扩展', false, error.response?.data?.error?.message || error.message);
    return null;
  }
}

// 5. 测试视频生成流程
async function testVideoGeneration() {
  try {
    console.log('\n🎬 测试视频生成流程...');
    
    // 创建视频任务
    const createResponse = await axios.post(`${BASE_URL}/video/create`, {
      title: '测试视频',
      description: '端到端测试',
      slides: [
        {
          imageUrl: 'https://picsum.photos/1280/720',
          caption: '第一张幻灯片',
          voiceText: '这是第一张幻灯片的配音。',
          duration: 5,
          transition: 'fade'
        },
        {
          imageUrl: 'https://picsum.photos/1280/721',
          caption: '第二张幻灯片',
          voiceText: '这是第二张幻灯片的配音。',
          duration: 5,
          transition: 'slideLeft'
        }
      ],
      config: {
        resolution: '720p',
        frameRate: 30,
        voiceType: 'standardFemale',
        voiceSpeed: 1.0,
        backgroundMusic: 'gentle',
        subtitleEnabled: true,
        subtitlePosition: 'bottom',
        aiImageExpansion: false,
        expansionStyle: 'cinematic'
      }
    });
    
    if (!createResponse.data.success) {
      logTest('创建视频任务', false, '创建任务失败');
      return;
    }
    
    const taskId = createResponse.data.data.taskId;
    logTest('创建视频任务', true, `任务ID: ${taskId}`);
    
    // 轮询任务状态
    console.log('   ⏳ 等待视频生成完成 (约 30-60 秒)...');
    let completed = false;
    let attempts = 0;
    const maxAttempts = 30;
    
    while (!completed && attempts < maxAttempts) {
      await sleep(3000);
      attempts++;
      
      try {
        const statusResponse = await axios.get(`${BASE_URL}/video/status/${taskId}`);
        const status = statusResponse.data.data;
        
        process.stdout.write(`\r   进度: ${Math.round(status.progress * 100)}% - ${status.message}`);
        
        if (status.status === 'completed') {
          completed = true;
          console.log('\n');
          logTest('视频生成', true, `视频地址: ${status.outputUrl}`);
          return status.outputUrl;
        } else if (status.status === 'failed') {
          completed = true;
          console.log('\n');
          logTest('视频生成', false, status.error || '任务失败');
          return null;
        }
      } catch (error) {
        console.log(`\n   ⚠️  查询状态失败: ${error.message}`);
      }
    }
    
    if (!completed) {
      console.log('\n');
      logTest('视频生成', false, '等待超时，请手动查询任务状态');
      console.log(`   任务ID: ${taskId}`);
      console.log(`   查询命令: curl ${BASE_URL}/video/status/${taskId}`);
    }
    
  } catch (error) {
    logTest('视频生成流程', false, error.response?.data?.error?.message || error.message);
  }
}

// 6. 测试队列状态
async function testQueueStatus() {
  try {
    const response = await axios.get(`${BASE_URL}/video/queue-status`);
    if (response.data.success) {
      const queue = response.data.data;
      logTest('队列状态', true, 
        `等待: ${queue.waiting}, 运行: ${queue.active}, 完成: ${queue.completed}, 失败: ${queue.failed}`);
    }
  } catch (error) {
    logTest('队列状态', false, error.message);
  }
}

// 主测试流程
async function runTests() {
  const startTime = Date.now();
  
  // 基础测试
  const healthy = await testHealth();
  if (!healthy) {
    console.log('\n❌ 后端服务未启动，请先运行 npm run dev');
    process.exit(1);
  }
  
  await testVoiceList();
  await testQueueStatus();
  
  // API 功能测试
  await testTTS();
  await testImageExpansion();
  await testVideoGeneration();
  
  // 打印测试报告
  const duration = ((Date.now() - startTime) / 1000).toFixed(1);
  
  console.log('\n' + '='.repeat(50));
  console.log('📊 测试报告');
  console.log('='.repeat(50));
  console.log(`✅ 通过: ${results.passed}`);
  console.log(`❌ 失败: ${results.failed}`);
  console.log(`⏱️  耗时: ${duration}s`);
  console.log('='.repeat(50));
  
  if (results.failed > 0) {
    console.log('\n失败的测试:');
    results.tests.filter(t => !t.success).forEach(t => {
      console.log(`  ❌ ${t.name}: ${t.message}`);
    });
    process.exit(1);
  } else {
    console.log('\n🎉 所有测试通过！');
    process.exit(0);
  }
}

runTests().catch(error => {
  console.error('测试失败:', error);
  process.exit(1);
});
