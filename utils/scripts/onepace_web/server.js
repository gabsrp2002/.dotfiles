const express = require('express');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const PORT = process.env.PORT || 3000;
const ONE_PACE_DIR = process.env.ONE_PACE_DIR || path.join(os.homedir(), 'one_pace');
const STATE_FILE = path.join(ONE_PACE_DIR, '.one_pace_state.json');
const WATCH_LATER_DIR = path.join(os.homedir(), '.config', 'mpv', 'watch_later');

// Helper to format arc directory: 25_fishman_island -> 25. Fishman Island
function formatArc(dir) {
  if (!dir) return '';
  const parts = dir.split('_');
  const num = parts[0];
  const nameParts = parts.slice(1);
  const title = nameParts
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
  return `${num}. ${title}`;
}

// Helper to format episode filename: ep02.mp4 -> Episode 02
function formatEpisode(fname) {
  if (!fname) return '';
  const base = path.basename(fname, path.extname(fname));
  const digits = base.replace(/^ep/i, '');
  if (/^\d+$/.test(digits)) {
    const num = parseInt(digits, 10);
    return `Episode ${num < 10 ? '0' + num : num}`;
  }
  return fname;
}

// Helper to format timestamp seconds to mm:ss or hh:mm:ss
function formatTime(seconds) {
  if (!seconds || isNaN(seconds)) return '00:00';
  const sec = Math.floor(seconds);
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  const pad = n => n < 10 ? '0' + n : n;
  if (h > 0) {
    return `${h}:${pad(m)}:${pad(s)}`;
  }
  return `${pad(m)}:${pad(s)}`;
}

// Get mpv watch_later timestamp if available
function getMpvWatchLaterTimestamp(filePath) {
  if (!fs.existsSync(WATCH_LATER_DIR)) return 0;
  try {
    const hash = crypto.createHash('md5').update(filePath).digest('hex').toUpperCase();
    const wlFile = path.join(WATCH_LATER_DIR, hash);
    if (fs.existsSync(wlFile)) {
      const content = fs.readFileSync(wlFile, 'utf8');
      const match = content.match(/^start=([0-9.]+)/m);
      if (match) {
        return parseFloat(match[1]);
      }
    }
  } catch (e) {
    console.error('Error reading mpv watch_later file:', e);
  }
  return 0;
}

// Read state JSON
function readState() {
  if (fs.existsSync(STATE_FILE)) {
    try {
      const data = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
      let ts = parseFloat(data.timestamp) || 0;

      // Fallback to mpv watch_later if timestamp is not in state file
      if (ts === 0 && data.last_arc && data.last_episode) {
        const fullPath = path.join(ONE_PACE_DIR, data.last_arc, data.last_episode);
        ts = getMpvWatchLaterTimestamp(fullPath);
      }

      return {
        last_arc: data.last_arc || '',
        last_episode: data.last_episode || '',
        timestamp: ts
      };
    } catch (e) {
      console.error('Error parsing state file:', e);
    }
  }
  return { last_arc: '', last_episode: '', timestamp: 0 };
}

// Write state JSON
function writeState(arc, episode, timestamp = 0) {
  const state = {
    last_arc: arc,
    last_episode: episode,
    timestamp: Math.floor(parseFloat(timestamp) || 0)
  };
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), 'utf8');
}

// Get non-empty arc folders sorted numerically
function getArcFolders() {
  if (!fs.existsSync(ONE_PACE_DIR)) return [];
  const entries = fs.readdirSync(ONE_PACE_DIR, { withFileTypes: true });
  const arcDirs = entries
    .filter(e => e.isDirectory() && !e.name.startsWith('.'))
    .map(e => e.name);

  arcDirs.sort((a, b) => {
    const numA = parseInt(a.split('_')[0], 10) || 0;
    const numB = parseInt(b.split('_')[0], 10) || 0;
    return numA - numB;
  });

  const result = [];
  for (const dir of arcDirs) {
    const dirPath = path.join(ONE_PACE_DIR, dir);
    const files = fs.readdirSync(dirPath).filter(f => f.startsWith('ep') && f.endsWith('.mp4'));
    files.sort((a, b) => {
      const numA = parseInt(a.replace(/\D/g, ''), 10) || 0;
      const numB = parseInt(b.replace(/\D/g, ''), 10) || 0;
      return numA - numB;
    });

    if (files.length > 0) {
      result.push({
        id: dir,
        title: formatArc(dir),
        epCount: files.length,
        episodes: files.map(f => ({
          filename: f,
          title: formatEpisode(f)
        }))
      });
    }
  }
  return result;
}

// API Routes
app.get('/api/status', (req, res) => {
  const state = readState();
  const arcs = getArcFolders();
  let totalEps = 0;
  arcs.forEach(a => totalEps += a.epCount);

  res.json({
    last_arc: state.last_arc,
    last_episode: state.last_episode,
    timestamp: state.timestamp,
    timestamp_formatted: formatTime(state.timestamp),
    last_arc_formatted: state.last_arc ? formatArc(state.last_arc) : 'None',
    last_episode_formatted: state.last_episode ? formatEpisode(state.last_episode) : 'None',
    total_arcs: arcs.length,
    total_eps: totalEps
  });
});

app.get('/api/arcs', (req, res) => {
  res.json(getArcFolders());
});

app.post('/api/state', (req, res) => {
  const { arc, episode, timestamp } = req.body;
  if (!arc || !episode) {
    return res.status(400).json({ error: 'Missing arc or episode parameter' });
  }
  writeState(arc, episode, timestamp || 0);
  res.json({ success: true, arc, episode, timestamp: timestamp || 0 });
});

// Stream endpoint with HTTP 206 Partial Content Range support
app.get('/stream/:arc/:episode', (req, res) => {
  const { arc, episode } = req.params;
  const filePath = path.join(ONE_PACE_DIR, arc, episode);

  if (!fs.existsSync(filePath)) {
    return res.status(404).send('Episode video file not found');
  }

  const stat = fs.statSync(filePath);
  const fileSize = stat.size;
  const range = req.headers.range;

  if (range) {
    const parts = range.replace(/bytes=/, '').split('-');
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
    const chunksize = (end - start) + 1;

    const head = {
      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunksize,
      'Content-Type': 'video/mp4',
    };

    res.writeHead(206, head);
    const fileStream = fs.createReadStream(filePath, { start, end });
    fileStream.pipe(res);
  } else {
    const head = {
      'Content-Length': fileSize,
      'Content-Type': 'video/mp4',
    };
    res.writeHead(200, head);
    fs.createReadStream(filePath).pipe(res);
  }
});

// Download endpoint for saving video files offline on mobile
app.get('/download/:arc/:episode', (req, res) => {
  const { arc, episode } = req.params;
  const filePath = path.join(ONE_PACE_DIR, arc, episode);

  if (!fs.existsSync(filePath)) {
    return res.status(404).send('Episode video file not found');
  }

  const downloadFilename = `${arc}_${episode}`;
  res.download(filePath, downloadFilename);
});

app.listen(PORT, () => {
  console.log(`================================================`);
  console.log(`🏴‍☠️ One Pace Web Server running at:`);
  console.log(`   http://localhost:${PORT}`);
  console.log(`   ONE_PACE_DIR: ${ONE_PACE_DIR}`);
  console.log(`================================================`);
});
