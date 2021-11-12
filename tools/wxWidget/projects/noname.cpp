///////////////////////////////////////////////////////////////////////////
// C++ code generated with wxFormBuilder (version 3.10.1-0-g8feb16b3)
// http://www.wxformbuilder.org/
//
// PLEASE DO *NOT* EDIT THIS FILE!
///////////////////////////////////////////////////////////////////////////

#include "noname.h"

///////////////////////////////////////////////////////////////////////////

MyFrame1::MyFrame1( wxWindow* parent, wxWindowID id, const wxString& title, const wxPoint& pos, const wxSize& size, long style, const wxString& name ) : wxFrame( parent, id, title, pos, size, style, name )
{
	this->SetSizeHints( wxSize( 500,500 ), wxDefaultSize );
	m_mgr.SetManagedWindow(this);
	m_mgr.SetFlags(wxAUI_MGR_DEFAULT);

	m_notebook4 = new wxNotebook( this, wxID_ANY, wxDefaultPosition, wxSize( 100,100 ), 0 );
	m_mgr.AddPane( m_notebook4, wxAuiPaneInfo() .Left() .CaptionVisible( false ).CloseButton( false ).Dock().Resizable().FloatingSize( wxDefaultSize ).CentrePane() );

	m_panel8 = new wxPanel( m_notebook4, wxID_ANY, wxDefaultPosition, wxSize( -1,-1 ), wxTAB_TRAVERSAL );
	wxBoxSizer* bSizer2;
	bSizer2 = new wxBoxSizer( wxVERTICAL );

	m_textCtrl3 = new wxTextCtrl( m_panel8, wxID_ANY, wxT("Setting up..."), wxDefaultPosition, wxDefaultSize, 0 );
	m_textCtrl3->Enable( false );

	bSizer2->Add( m_textCtrl3, 0, wxALIGN_CENTER|wxALL, 10 );

	m_button8 = new wxButton( m_panel8, wxID_ANY, wxT("Redo Setup"), wxDefaultPosition, wxDefaultSize, 0 );
	bSizer2->Add( m_button8, 0, wxALIGN_CENTER|wxALL, 10 );


	m_panel8->SetSizer( bSizer2 );
	m_panel8->Layout();
	bSizer2->Fit( m_panel8 );
	m_notebook4->AddPage( m_panel8, wxT("Setup"), true );
	m_panel9 = new wxPanel( m_notebook4, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL );
	wxGridSizer* gSizer1;
	gSizer1 = new wxGridSizer( 1, 2, 0, 0 );


	m_panel9->SetSizer( gSizer1 );
	m_panel9->Layout();
	gSizer1->Fit( m_panel9 );
	m_notebook4->AddPage( m_panel9, wxT("Puppets"), false );

	m_timer1.SetOwner( this, wxID_ANY );

	m_mgr.Update();
	this->Centre( wxBOTH );

	// Connect Events
	m_button8->Connect( wxEVT_COMMAND_BUTTON_CLICKED, wxCommandEventHandler( MyFrame1::m_button8OnButtonClick ), NULL, this );
	this->Connect( wxID_ANY, wxEVT_TIMER, wxTimerEventHandler( MyFrame1::m_timer1OnTimer ) );
}

MyFrame1::~MyFrame1()
{
	// Disconnect Events
	m_button8->Disconnect( wxEVT_COMMAND_BUTTON_CLICKED, wxCommandEventHandler( MyFrame1::m_button8OnButtonClick ), NULL, this );
	this->Disconnect( wxID_ANY, wxEVT_TIMER, wxTimerEventHandler( MyFrame1::m_timer1OnTimer ) );

	m_mgr.UnInit();

}
