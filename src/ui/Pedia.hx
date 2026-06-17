// pedia window - topics tree + article contents

package ui;

import mods.AssetPath;
import js.Browser;
import js.html.DivElement;
import js.html.InputElement;

import game.Game;
import const.PediaConst;

class Pedia extends UIWindow
{
  var pediaList: DivElement;     // .pd-list (groups + topics)
  var pediaInner: DivElement;    // .pd-inner (article render target)
  var crumb: DivElement;         // .pd-crumb breadcrumb
  var search: InputElement;      // search field
  var searchWrap: DivElement;    // wraps search + clear button
  var groupInfos: Array<_GroupInfoUI>;
  var activeTopic: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-pedia');

      addCorners();

      // titlebar with breadcrumb
      var titlebar = Browser.document.createDivElement();
      titlebar.className = 'pd-titlebar';
      titlebar.innerHTML = '<span class="pd-title">PEDIA</span>';
      crumb = Browser.document.createDivElement();
      crumb.className = 'pd-crumb';
      titlebar.appendChild(crumb);
      window.appendChild(titlebar);

      // body: nav (search + list) + content
      var body = Browser.document.createDivElement();
      body.className = 'pd-body';
      window.appendChild(body);

      var nav = Browser.document.createDivElement();
      nav.className = 'pd-nav';
      body.appendChild(nav);
      searchWrap = Browser.document.createDivElement();
      searchWrap.className = 'pd-searchwrap';
      nav.appendChild(searchWrap);
      search = Browser.document.createInputElement();
      search.className = 'pd-search';
      search.type = 'text';
      search.placeholder = 'Search topics...';
      search.oninput = function (e) {
        searchWrap.classList.toggle('has', search.value != '');
        filter();
      };
      searchWrap.appendChild(search);
      var clear = Browser.document.createDivElement();
      clear.className = 'pd-clear';
      clear.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/></svg>';
      clear.onclick = function (e) {
        search.value = '';
        searchWrap.classList.remove('has');
        filter();
        search.focus();
      };
      searchWrap.appendChild(clear);

      pediaList = Browser.document.createDivElement();
      pediaList.className = 'pd-list';
      nav.appendChild(pediaList);

      var content = Browser.document.createDivElement();
      content.className = 'pd-content';
      pediaInner = Browser.document.createDivElement();
      pediaInner.className = 'pd-inner pd-empty';
      pediaInner.innerHTML = 'Pick an article to read.';
      content.appendChild(pediaInner);
      body.appendChild(content);

      buildList();

      addWinClose(function (e) {
        game.scene.sounds.play('click-menu');
        game.ui.state = UISTATE_MAINMENU;
      });
    }

// wipe + re-populate the topics list (mod loader calls after appending groups)
  public function rebuild()
    {
      pediaList.innerHTML = '';
      buildList();
    }

// build the topics tree from PediaConst.contents
  function buildList()
    {
      groupInfos = [];
      for (groupContents in PediaConst.contents)
        {
          var topics: Array<_TopicInfoUI> = [];
          // group header: caret + name + unlocked count
          var header = Browser.document.createDivElement();
          header.className = 'pd-group';
          var wrap = Browser.document.createDivElement();
          wrap.className = 'pd-topics';
          var inner = Browser.document.createDivElement();
          inner.className = 'pd-topics-in';
          wrap.appendChild(inner);

          var groupInfo: _GroupInfoUI = {
            isOpen: true,
            header: header,
            wrap: wrap,
            topics: topics,
          };
          groupInfos.push(groupInfo);

          var i = 0;
          for (article in groupContents.articles)
            {
              i++;
              var num = (i < 10 ? '0' : '') + i;
              var topic = Browser.document.createDivElement();
              topic.className = 'pd-topic';
              var state = game.profile.getPediaArticle(article.id);
              var topicInfo: _TopicInfoUI = {
                id: article.id,
                element: topic,
                search: stripTags(article.name).toLowerCase(),
                locked: (state == null),
              };
              topics.push(topicInfo);
              renderTopic(topicInfo, num, (state == 1));
              topic.style.display = (state != null ? 'flex' : 'none');
              topic.onclick = function (e) {
                game.scene.sounds.play('click-submenu');
                showArticle(article, topicInfo, groupContents.name, num);
              };
              inner.appendChild(topic);
            }

          // header markup: count reflects unlocked topics
          header.innerHTML = '<span class="pd-caret">&rsaquo;</span>' +
            '<span class="pd-gname">' + groupContents.name + '</span>' +
            '<span class="pd-count">' + countUnlocked(groupInfo) + '</span>';
          header.onclick = function (e) {
            if (search.value != '')
              return;
            game.scene.sounds.play('click-submenu');
            groupInfo.isOpen = !groupInfo.isOpen;
            header.classList.toggle('collapsed', !groupInfo.isOpen);
            wrap.classList.toggle('collapsed', !groupInfo.isOpen);
          };
          pediaList.appendChild(header);
          pediaList.appendChild(wrap);
        }
    }

// render a topic row (index number + name, optional per-article font, unread dot)
  function renderTopic(t: _TopicInfoUI, num: String, isNew: Bool)
    {
      var article = PediaConst.getArticle(t.id);
      var fontStyle = (article.font != null ? ' style="font-size: ' + article.font + '%"' : '');
      t.element.classList.toggle('new', isNew);
      t.element.innerHTML = '<span class="pd-idx">' + num + '</span>' +
        '<span class="pd-tname"' + fontStyle + '>' + article.name + '</span>';
    }

// render an article into the content pane
  function showArticle(article: Dynamic, t: _TopicInfoUI, group: String, num: String)
    {
      if (activeTopic != null)
        activeTopic.classList.remove('active');
      t.element.classList.add('active');
      t.element.classList.remove('new');
      activeTopic = t.element;

      var html = '<div class="pd-kicker">' + group + ' · ' + num + '</div>' +
        '<h3 class="pd-h3">' + article.name + '</h3>';
      if (article.img != null)
        html += '<span class="pd-imgwrap"><img class="pd-img" src="' +
          AssetPath.resolve('img/' + article.img + '.jpg') +
          '" alt="" onerror="this.parentElement.style.display=\'none\'"></span>';
      html += '<div class="pd-text">' + article.text + '</div>';
      pediaInner.classList.remove('pd-empty');
      pediaInner.innerHTML = html;
      // restart the fade-up entrance
      pediaInner.classList.remove('pd-anim');
      untyped pediaInner.offsetWidth;
      pediaInner.classList.add('pd-anim');
      pediaInner.parentElement.scrollTop = 0;
      crumb.innerHTML = '/ ' + group + ' / <b>' + stripTags(article.name) + '</b>';

      game.profile.markPediaArticle(t.id);
    }

// live search/filter: hide non-matching topics, expand groups, hide empty groups
  function filter()
    {
      var q = StringTools.trim(search.value).toLowerCase();
      for (g in groupInfos)
        {
          if (q != '')
            {
              var any = false;
              for (o in g.topics)
                {
                  // locked topics never appear
                  var match = (!o.locked && o.search.indexOf(q) >= 0);
                  o.element.style.display = (match ? 'flex' : 'none');
                  if (match)
                    any = true;
                }
              // expand to reveal matches while searching
              g.wrap.classList.remove('collapsed');
              g.header.classList.remove('collapsed');
              g.header.style.display = (any ? 'flex' : 'none');
            }
          else
            {
              for (o in g.topics)
                o.element.style.display = (o.locked ? 'none' : 'flex');
              g.wrap.classList.toggle('collapsed', !g.isOpen);
              g.header.classList.toggle('collapsed', !g.isOpen);
              g.header.style.display = 'flex';
            }
        }
    }

// reveal a newly-unlocked article
  public function newArticle(id: String)
    {
      for (g in groupInfos)
        for (t in g.topics)
          if (t.id == id)
            {
              t.locked = false;
              var num = indexOfTopic(g, t);
              renderTopic(t, num, true);
              updateCount(g);
              if (g.isOpen &&
                  search.value == '')
                t.element.style.display = 'flex';
              return;
            }
    }

// count unlocked topics in a group
  function countUnlocked(g: _GroupInfoUI): Int
    {
      var n = 0;
      for (t in g.topics)
        if (!t.locked)
          n++;
      return n;
    }

// refresh a group header's unlocked count chip
  function updateCount(g: _GroupInfoUI)
    {
      var chip = g.header.querySelector('.pd-count');
      if (chip != null)
        chip.innerHTML = '' + countUnlocked(g);
    }

// two-digit display index of a topic within its group
  function indexOfTopic(g: _GroupInfoUI, t: _TopicInfoUI): String
    {
      var i = g.topics.indexOf(t) + 1;
      return (i < 10 ? '0' : '') + i;
    }

// strip html tags for search/breadcrumb plain text
  function stripTags(s: String): String
    {
      return (~/<[^>]+>/g).replace(s, '');
    }

  override function update()
    {
      pediaInner.className = 'pd-inner pd-empty';
      pediaInner.innerHTML = 'Pick an article to read.';
      crumb.innerHTML = '';
      if (activeTopic != null)
        {
          activeTopic.classList.remove('active');
          activeTopic = null;
        }
    }
}

typedef _GroupInfoUI = {
  isOpen: Bool,
  header: DivElement,
  wrap: DivElement,
  topics: Array<_TopicInfoUI>,
};

typedef _TopicInfoUI = {
  id: String,
  element: DivElement,
  search: String,
  locked: Bool,
}
