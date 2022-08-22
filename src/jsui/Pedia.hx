// pedia window - list of topics and text

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.LegendElement;
import js.html.Element;

import game.Game;
import const.PediaConst;

class Pedia extends UIWindow
{
  var pediaList: DivElement;
  var pediaContents: DivElement;
  var groupInfos: Array<_GroupInfoUI>;

  public function new(g: Game)
    {
      super(g, 'window-pedia');
      window.style.borderImage = "url('./img/window-log.png') 215 fill / 1 / 0 stretch";

      var ret = addBlockExtended(window, 'window-pedia-list', 'TOPICS');
      pediaList = ret.text;
      pediaContents = addBlock(window, 'window-pedia-contents', 'CONTENTS');

      // add topics list items
      groupInfos = [];
      for (groupContents in PediaConst.contents)
        {
          var group = Browser.document.createDivElement();
          var groupInfo: _GroupInfoUI = {
            isOpen: false,
            element: group,
            topics: [],
          };
          group.className = 'window-pedia-group-item actions-item';
          group.innerHTML = '+ ' + groupContents.name;
          group.onclick = function (e) {
            groupInfo.isOpen = !groupInfo.isOpen;
            var sym = (groupInfo.isOpen ? '- ' : '+ ');
            group.innerHTML = sym + groupContents.name;
            // show topics
            for (t in groupInfo.topics)
              {
                var isVisible = groupInfo.isOpen;
                if (isVisible)
                  {
                    var state = game.profile.getPediaArticle(t.id);
                    if (state == null)
                      continue;
                    updateTopic(t, (state == 1));
                  }

                t.element.style.display =
                  (isVisible ? 'flex' : 'none');
              }
          }
          pediaList.appendChild(group);
          for (article in groupContents.articles)
            {
              var topic = Browser.document.createDivElement();
              topic.className = 'window-pedia-topic-item actions-item';
              topic.style.display = 'none';
              pediaList.appendChild(topic);
              var topicInfo: _TopicInfoUI = {
                id: article.id,
                element: topic,
              };
              groupInfo.topics.push(topicInfo);
              topic.onclick = function (e) {
                pediaContents.innerHTML =
                  Const.col('gray', '<h3>' + article.name + '</h3><br>') +
                  Const.col('pedia', article.text);
                updateTopic(topicInfo, false);
                game.profile.markPediaArticle(topicInfo.id);
              }
            }
        }

      addCloseButton();
      close.onclick = function (e) {
        game.ui.state = UISTATE_MAINMENU;
      }
    }

// show article as new
  public function newArticle(id: String)
    {
      for (g in groupInfos)
        for (t in g.topics)
          if (t.id == id)
            {
              updateTopic(t, true);
              t.element.style.display = 'flex';
              return;
            }
    }

// update topic display
  function updateTopic(t: _TopicInfoUI, isNew: Bool)
    {
      var article = PediaConst.getArticle(t.id);
      t.element.innerHTML =
        '&nbsp;&nbsp;<span style="font-size: ' +
        (article.font != null ? article.font : 100) +
        '%">' +
        article.name + (isNew ? '&#10069;' : '') + '</span>';
    }

// update topics list
  override function update()
    {
      pediaContents.innerHTML = "Pick an article to read.";
    }
}

typedef _GroupInfoUI = {
  isOpen: Bool,
  element: DivElement,
  topics: Array<_TopicInfoUI>,
};

typedef _TopicInfoUI = {
  id: String,
  element: DivElement,
}
