function SetDialogPopUpCenter()
    local text = "Center popups - "
    local ret = nil
    local name1 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark1 = "# _UtilityMark_DefaultPopup_position"
    local new1 = "		position = { x=-250 y=-450 } # _UtilityMark_DefaultPopup_position"
    ret = ReplaceLineAtCommentMark(name1, mark1, new1)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name2 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark2 = "# _UtilityMark_DefaultPopup_orientation"
    local new2 = "		orientation=\"CENTER\" # _UtilityMark_DefaultPopup_orientation"
    ret = ReplaceLineAtCommentMark(name2, mark2, new2)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name3 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark3 = "# _UtilityMark_CombatStartPopup_position"
    local new3 = "		position = { x=-250 y=-280 } # _UtilityMark_CombatStartPopup_position"
    ret = ReplaceLineAtCommentMark(name3, mark3, new3)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name4 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark4 = "# _UtilityMark_CombatStartPopup_orientation"
    local new4 = "		orientation=\"CENTER\" # _UtilityMark_CombatStartPopup_orientation"
    ret = ReplaceLineAtCommentMark(name4, mark4, new4)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)
end

function SetDialogPopUpLeft()
    local text = "Leftside popups - "
    local ret = nil
    local name1 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark1 = "# _UtilityMark_DefaultPopup_position"
    local new1 = "		position = { x=50 y=100 } # _UtilityMark_DefaultPopup_position"
    ret = ReplaceLineAtCommentMark(name1, mark1, new1)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name2 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark2 = "# _UtilityMark_DefaultPopup_orientation"
    local new2 = "		orientation=\"CENTER_RIGHT\" # _UtilityMark_DefaultPopup_orientation"
    ret = ReplaceLineAtCommentMark(name2, mark2, new2)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name3 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark3 = "# _UtilityMark_CombatStartPopup_position"
    local new3 = "		position = { x=50 y=100 } # _UtilityMark_CombatStartPopup_position"
    ret = ReplaceLineAtCommentMark(name3, mark3, new3)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name4 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark4 = "# _UtilityMark_CombatStartPopup_orientation"
    local new4 = "		orientation=\"CENTER_RIGHT\" # _UtilityMark_CombatStartPopup_orientation"
    ret = ReplaceLineAtCommentMark(name4, mark4, new4)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)
end

function SetEventPopUpCenter()
    local text = "Center events - "
    local ret = nil
    local name1 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eventwindow.gui"
    local mark1 = "# _UtilityMark_EventPopup_position"
    local new1 = "		position = { x=700 y=255 } # _UtilityMark_EventPopup_position"
    ret = ReplaceLineAtCommentMark(name1, mark1, new1)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)
end

function SetEventPopUpLeft()
    local text = "Leftside events - "
    local ret = nil
    local name1 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eventwindow.gui"
    local mark1 = "# _UtilityMark_EventPopup_position"
    local new1 = "		position = { x=0 y=255 } # _UtilityMark_EventPopup_position"
    ret = ReplaceLineAtCommentMark(name1, mark1, new1)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)
end
