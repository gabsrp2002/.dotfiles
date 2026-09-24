document.addEventListener('DOMContentLoaded', () => {
  // DOM Elements
  const heroTitle = document.getElementById('hero-title');
  const heroSubtitle = document.getElementById('hero-subtitle');
  const heroPlayBtn = document.getElementById('hero-play-btn');
  const heroDownloadBtn = document.getElementById('hero-download-btn');
  const heroTimeBadge = document.getElementById('hero-time-badge');
  const statArcs = document.getElementById('stat-arcs');
  const statEps = document.getElementById('stat-eps');
  const arcsContainer = document.getElementById('arcs-container');
  const searchInput = document.getElementById('search-input');
  const refreshBtn = document.getElementById('refresh-btn');

  const playerModal = document.getElementById('player-modal');
  const playerTitle = document.getElementById('player-title');
  const videoPlayer = document.getElementById('video-player');
  const closeModalBtn = document.getElementById('close-modal-btn');
  const modalDownloadBtn = document.getElementById('modal-download-btn');

  let currentStatus = null;
  let allArcs = [];
  let expandedArcId = null;
  let activeArcId = null;
  let activeEpFilename = null;
  let lastSyncTime = 0;

  // Sync playback position to server (throttled)
  async function syncProgress(force = false) {
    if (!activeArcId || !activeEpFilename) return;
    const now = Date.now();
    if (!force && (now - lastSyncTime < 4000)) return; // Sync every 4 seconds max

    lastSyncTime = now;
    const currentTime = Math.floor(videoPlayer.currentTime || 0);

    try {
      await fetch('/api/state', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          arc: activeArcId,
          episode: activeEpFilename,
          timestamp: currentTime
        })
      });
    } catch (err) {
      console.error('Failed to sync progress:', err);
    }
  }

  // Fetch initial data
  async function fetchData() {
    try {
      const [statusRes, arcsRes] = await Promise.all([
        fetch('/api/status'),
        fetch('/api/arcs')
      ]);

      currentStatus = await statusRes.json();
      allArcs = await arcsRes.json();

      updateUI();
    } catch (err) {
      console.error('Error loading data:', err);
      heroTitle.textContent = 'Connection Error';
      heroSubtitle.textContent = 'Could not reach One Pace server';
    }
  }

  // Update UI with fetched data
  function updateUI() {
    if (!currentStatus || !allArcs) return;

    // Stats
    statArcs.textContent = currentStatus.total_arcs;
    statEps.textContent = currentStatus.total_eps;

    // Hero
    if (currentStatus.last_arc && currentStatus.last_episode) {
      heroTitle.textContent = currentStatus.last_arc_formatted;
      heroSubtitle.textContent = currentStatus.last_episode_formatted;
      heroPlayBtn.disabled = false;
      heroDownloadBtn.disabled = false;
      heroDownloadBtn.href = `/download/${currentStatus.last_arc}/${currentStatus.last_episode}`;

      if (currentStatus.timestamp && currentStatus.timestamp > 0) {
        heroTimeBadge.textContent = `@ ${currentStatus.timestamp_formatted}`;
        heroTimeBadge.classList.remove('hidden');
      } else {
        heroTimeBadge.classList.add('hidden');
      }

      if (!expandedArcId) {
        expandedArcId = currentStatus.last_arc;
      }
    } else if (allArcs.length > 0) {
      const firstArc = allArcs[0];
      const firstEp = firstArc.episodes[0];
      heroTitle.textContent = firstArc.title;
      heroSubtitle.textContent = firstEp.title;
      currentStatus.last_arc = firstArc.id;
      currentStatus.last_episode = firstEp.filename;
      currentStatus.timestamp = 0;
      heroPlayBtn.disabled = false;
      heroDownloadBtn.disabled = false;
      heroDownloadBtn.href = `/download/${firstArc.id}/${firstEp.filename}`;
      heroTimeBadge.classList.add('hidden');
      expandedArcId = firstArc.id;
    }

    renderArcs(allArcs);
  }

  // Render Arcs List
  function renderArcs(arcsToRender) {
    arcsContainer.innerHTML = '';
    const query = (searchInput.value || '').toLowerCase().trim();

    const filtered = arcsToRender.filter(arc => {
      if (!query) return true;
      if (arc.title.toLowerCase().includes(query)) return true;
      return arc.episodes.some(ep => ep.title.toLowerCase().includes(query) || ep.filename.toLowerCase().includes(query));
    });

    if (filtered.length === 0) {
      arcsContainer.innerHTML = `<div class="loading-spinner">No matching arcs found</div>`;
      return;
    }

    filtered.forEach(arc => {
      const arcCard = document.createElement('div');
      arcCard.className = 'arc-card';
      if (arc.id === currentStatus.last_arc) {
        arcCard.classList.add('active-arc');
      }

      const isExpanded = arc.id === expandedArcId || query.length > 0;

      const arcHeader = document.createElement('div');
      arcHeader.className = 'arc-header';
      arcHeader.innerHTML = `
        <span class="arc-title">${arc.title}</span>
        <span class="arc-badge">${arc.epCount} ep</span>
      `;

      arcHeader.addEventListener('click', () => {
        expandedArcId = (expandedArcId === arc.id) ? null : arc.id;
        renderArcs(allArcs);
      });

      arcCard.appendChild(arcHeader);

      if (isExpanded) {
        const grid = document.createElement('div');
        grid.className = 'episodes-grid';

        arc.episodes.forEach(ep => {
          const isLastWatched = (arc.id === currentStatus.last_arc && ep.filename === currentStatus.last_episode);
          const epItem = document.createElement('div');
          epItem.className = `episode-item ${isLastWatched ? 'is-last-watched' : ''}`;

          let tsTag = '';
          if (isLastWatched && currentStatus.timestamp > 0) {
            tsTag = ` (@ ${currentStatus.timestamp_formatted})`;
          }

          epItem.innerHTML = `
            <div>
              <span class="ep-title">${ep.title}</span>
              ${isLastWatched ? `<span class="last-tag">LAST WATCHED${tsTag}</span>` : ''}
            </div>
            <div class="ep-actions">
              <button class="action-icon-btn play-ep-btn" title="Stream">▶</button>
              <a class="action-icon-btn" href="/download/${arc.id}/${ep.filename}" download title="Download">⬇</a>
            </div>
          `;

          const playBtn = epItem.querySelector('.play-ep-btn');
          playBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            const startTs = isLastWatched ? (currentStatus.timestamp || 0) : 0;
            openPlayer(arc.id, ep.filename, arc.title, ep.title, startTs);
          });

          grid.appendChild(epItem);
        });

        arcCard.appendChild(grid);
      }

      arcsContainer.appendChild(arcCard);
    });
  }

  // Find next episode sequentially (current arc -> next arc)
  function getNextEpisode(arcId, epFilename) {
    if (!allArcs || allArcs.length === 0) return null;

    const arcIndex = allArcs.findIndex(a => a.id === arcId);
    if (arcIndex === -1) return null;

    const arc = allArcs[arcIndex];
    const epIndex = arc.episodes.findIndex(e => e.filename === epFilename);
    if (epIndex === -1) return null;

    // Next episode in same arc
    if (epIndex + 1 < arc.episodes.length) {
      const nextEp = arc.episodes[epIndex + 1];
      return {
        arcId: arc.id,
        arcTitle: arc.title,
        epFilename: nextEp.filename,
        epTitle: nextEp.title
      };
    }

    // Next episode in next arc
    if (arcIndex + 1 < allArcs.length) {
      const nextArc = allArcs[arcIndex + 1];
      if (nextArc.episodes && nextArc.episodes.length > 0) {
        const nextEp = nextArc.episodes[0];
        return {
          arcId: nextArc.id,
          arcTitle: nextArc.title,
          epFilename: nextEp.filename,
          epTitle: nextEp.title
        };
      }
    }

    return null;
  }

  // Open Video Player Modal
  async function openPlayer(arcId, epFilename, arcTitle, epTitle, startTimestamp = 0) {
    activeArcId = arcId;
    activeEpFilename = epFilename;

    playerTitle.textContent = `${arcTitle} — ${epTitle}`;
    videoPlayer.src = `/stream/${arcId}/${epFilename}`;
    modalDownloadBtn.href = `/download/${arcId}/${epFilename}`;

    playerModal.classList.remove('hidden');

    if (startTimestamp > 0) {
      videoPlayer.addEventListener('loadedmetadata', function onMeta() {
        videoPlayer.currentTime = startTimestamp;
        videoPlayer.removeEventListener('loadedmetadata', onMeta);
      });
    }

    videoPlayer.play().catch(e => console.log('Autoplay prevented:', e));

    // Save initial state (start of new episode reset timestamp to startTimestamp)
    syncProgress(true);
  }

  // Close Video Player Modal
  function closePlayer() {
    syncProgress(true);
    videoPlayer.pause();
    videoPlayer.src = '';
    playerModal.classList.add('hidden');
    activeArcId = null;
    activeEpFilename = null;
    fetchData();
  }

  // Event Listeners
  videoPlayer.addEventListener('timeupdate', () => syncProgress(false));
  videoPlayer.addEventListener('pause', () => syncProgress(true));

  // Automatically start the next episode when current episode ends
  videoPlayer.addEventListener('ended', async () => {
    // Reset timestamp for completed episode
    await syncProgress(true);

    const next = getNextEpisode(activeArcId, activeEpFilename);
    if (next) {
      console.log(`▶ Auto-playing next episode: ${next.arcTitle} / ${next.epTitle}`);
      openPlayer(next.arcId, next.epFilename, next.arcTitle, next.epTitle, 0);
    } else {
      closePlayer();
    }
  });

  heroPlayBtn.addEventListener('click', () => {
    if (currentStatus && currentStatus.last_arc && currentStatus.last_episode) {
      openPlayer(
        currentStatus.last_arc,
        currentStatus.last_episode,
        currentStatus.last_arc_formatted,
        currentStatus.last_episode_formatted,
        currentStatus.timestamp || 0
      );
    }
  });

  closeModalBtn.addEventListener('click', closePlayer);
  refreshBtn.addEventListener('click', fetchData);

  searchInput.addEventListener('input', () => {
    renderArcs(allArcs);
  });

  // Initial load
  fetchData();
});
