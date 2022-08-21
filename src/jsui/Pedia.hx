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
  var groupInfos: Array<{
    isOpen: Bool,
    element: DivElement,
    topics: Array<DivElement>,
  }>;

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
          var groupInfo = {
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
            for (t in groupInfo.topics)
              t.style.display = (groupInfo.isOpen ? 'flex' : 'none');
          }
          pediaList.appendChild(group);
          for (article in groupContents.articles)
            {
              var topic = Browser.document.createDivElement();
              topic.className = 'window-pedia-topic-item actions-item';
              topic.innerHTML = '&nbsp;&nbsp;<span style="font-size: ' + (article.font != null ? article.font : 100) + '%">' +
                article.name + '</span>';
              topic.style.display = 'none';
              pediaList.appendChild(topic);
              groupInfo.topics.push(topic);
              topic.onclick = function (e) {
                pediaContents.innerHTML =
                  '<h3>' + article.name + '</h3><br>' +
                  article.text;
              }
            }
        }

      addCloseButton();
      close.onclick = function (e) {
        game.ui.state = UISTATE_MAINMENU;
      }
    }

// update topics list
  override function update()
    {
      pediaContents.innerHTML = "Pick an article to read.";
    }
}

