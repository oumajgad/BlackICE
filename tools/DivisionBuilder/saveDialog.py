
from saveDialogGenerated import MyDialog1
from wx import App, KeyEvent, WXK_ESCAPE
from tech import Tech
from utils import get_save_tech_levels


class SaveDialog(MyDialog1):
    wx_app: App
    tech_list: list[Tech]

    def m_button_save_okOnButtonClick(self, event):
        if self.m_textCtrl_save_tag.IsEmpty() or len(self.m_textCtrl_save_tag.GetValue()) != 3:
            print("Please enter a valid TAG")
            return
        if len(self.m_filePicker1.GetPath()) == 0:
            print("Please select a save")
            return
        path = self.m_filePicker1.GetPath()
        print(path)
        tag = self.m_textCtrl_save_tag.GetValue()
        save_techs: dict[str, int] = get_save_tech_levels(path, tag)
        self.apply_save_tech_levels(save_techs)
        self.wx_app.ExitMainLoop()

    def m_button_save_noOnButtonClick(self, event):
        self.wx_app.ExitMainLoop()

    def MyDialog1OnCharHook(self, event: KeyEvent):
        if event.GetKeyCode() == WXK_ESCAPE:
            self.wx_app.ExitMainLoop()
        else:
            event.Skip()

    def apply_save_tech_levels(self, save_techs: dict[str, int]):
        for tech in self.tech_list:
            tech.level = int(save_techs.get(tech.name, 0))

    def MyDialog1OnClose(self, event):
        self.wx_app.ExitMainLoop()
