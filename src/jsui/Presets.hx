package jsui;

import game.Game;
import js.Browser.document;
import js.html.InputElement;
import js.html.SelectElement;

class Presets extends UIWindow
{
  var presetSelect: SelectElement;

  public function new(g: Game)
    {
      super(g, 'window-presets');

      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      // title
      var titleDiv = document.createDivElement();
      titleDiv.textContent = "PRESETS";
      titleDiv.id = "window-presets-title";
      window.appendChild(titleDiv);

      // first row - select + buttons
      var buttonContainer = document.createDivElement();
      buttonContainer.className = 'button-container';
      window.appendChild(buttonContainer);

      // preset select
      presetSelect = document.createSelectElement();
      presetSelect.id = 'preset-select';
      presetSelect.className = 'basic-select basic-input-text text';

      // preset title input
      var presetTitleInput = document.createInputElement();
      presetTitleInput.type = 'text';
      presetTitleInput.className = 'basic-input-text text';
      window.appendChild(presetTitleInput);

      // buttons
      var newButton = document.createButtonElement();
      newButton.innerHTML= "&#10010;";
      newButton.className = 'basic-button';
      var saveButton = document.createButtonElement();
      saveButton.innerHTML = "&#128427;";
      saveButton.className = 'basic-button';
      var deleteButton = document.createButtonElement();
      deleteButton.innerHTML = "&#10006;";
      deleteButton.className = 'basic-button';

      buttonContainer.appendChild(presetSelect);
      buttonContainer.appendChild(newButton);
      buttonContainer.appendChild(saveButton);
      buttonContainer.appendChild(deleteButton);

      // contents
      var contents = document.createDivElement();
      contents.className = 'window-presets-grid';
      window.appendChild(contents);

      // populate preset list
      updatePresetList();

      // create new preset
      newButton.onclick = function(e) {
        var newPresetName = "PRESET" + (game.profile.object.difficultyPresets.length + 1);
        var newOption = document.createOptionElement();
        newOption.textContent = newPresetName;
        presetSelect.appendChild(newOption);
        presetTitleInput.value = newPresetName;
        game.profile.object.difficultyPresets.push({
          name: newPresetName,
          settings: new haxe.DynamicAccess<Int>()
        });
        presetSelect.selectedIndex = game.profile.object.difficultyPresets.length - 1;
        // clear all radios
        var allRadios = contents.querySelectorAll(".basic-radio");
        for (rr in allRadios)
          {
            var r: InputElement = untyped rr;
            r.checked = (r.name.indexOf('0') > 0);
          }
      }

      // select preset from list
      presetSelect.onchange = function(e) {
        var selectedIndex = presetSelect.selectedIndex;
        var preset = game.profile.object.difficultyPresets[selectedIndex];
        presetTitleInput.value = preset.name;
        // populate difficulty settings from selected preset
        for (key in Difficulty.choices.keys())
          for (i in 0...3)
            {
              var radio: InputElement = cast contents.querySelector('[name="' + key + '-' + i + '"]');
              radio.checked =
                (preset.settings.get(key) - 1 == i);
            }
      }

      // preset headers
      var headerRow = document.createDivElement();
      headerRow.className = 'preset-header';

      // empty header for alignment
      var emptyHeader = document.createDivElement();
      emptyHeader.className = 'setting-title';
      headerRow.appendChild(emptyHeader);

      // difficulty headers
      var headerTitles = ["EASY", "NORMAL", "HARD"];
      for (title in headerTitles)
        {
          var header = document.createDivElement();
          header.textContent = title;
          header.className = 'header-title';
          headerRow.appendChild(header);
        }
      contents.appendChild(headerRow);

      // difficulty settings
      for (key in Difficulty.choices.keys()) {
        var choice = Difficulty.choices.get(key);
        var settingDiv = document.createDivElement();
        settingDiv.className = "setting-row";

        var title = document.createDivElement();
        title.textContent = choice.title;
        title.className = "setting-title";
        settingDiv.appendChild(title);

        // easy/normal/hard radio buttons
        for (i in 0...3) {
          var radio = document.createInputElement();
          radio.type = 'radio';
          radio.name = key + '-' + i;
          radio.value = i + '';
          radio.className = "basic-radio";
          if (i == 0)
            radio.checked = true;

          radio.onchange = function(e) {
            var allRadios = settingDiv.querySelectorAll(".basic-radio");
            for (r in allRadios)
              untyped r.checked = false;
            radio.checked = true;
          }

          settingDiv.appendChild(radio);
        }

        contents.appendChild(settingDiv);
      }

      // save button
      saveButton.onclick = function(e) {
        var selectedIndex = presetSelect.selectedIndex;
        var preset = game.profile.object.difficultyPresets[selectedIndex];
        preset.name = presetTitleInput.value;
        for (key in Difficulty.choices.keys())
          for (i in 0...3)
            {
              var radio: InputElement = cast contents.querySelector('[name="' + key + '-' + i + '"]');
              if (radio.checked)
                preset.settings.set(key, i + 1);
            }
        game.profile.save();
        updatePresetList();
      }

      // delete button
      deleteButton.onclick = function(e) {
        var selectedIndex = presetSelect.selectedIndex;
        if (selectedIndex >= 0) 
          {
            game.profile.object.difficultyPresets.splice(selectedIndex, 1);
            updatePresetList();
            if (presetSelect.options.length > 0)
              {
                presetSelect.selectedIndex = Std.int(Math.max(0, selectedIndex - 1));
                presetSelect.onchange(null);
              }
            else
              {
                presetTitleInput.value = "";
                // clear all radios
                var allRadios = contents.querySelectorAll(".basic-radio");
                for (r in allRadios)
                  untyped r.checked = false;
              }
            game.profile.save();
          }
      }

      addCloseButton();
      close.onclick = function (e) {
        // save current preset
        saveButton.onclick(null);
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_OPTIONS;
      }

      // auto-select first preset
      if (game.profile.object.difficultyPresets.length > 0)
        presetSelect.onchange(null);
    }

  // update preset list
  function updatePresetList()
    {
      var old = presetSelect.selectedIndex;
      presetSelect.innerHTML = '';
      for (preset in game.profile.object.difficultyPresets)
        {
          var option = document.createOptionElement();
          option.textContent = preset.name;
          presetSelect.appendChild(option);
        }
      if (old >= 0)
        presetSelect.selectedIndex =
          Std.int(Math.min(old, presetSelect.options.length - 1));
    }
}

