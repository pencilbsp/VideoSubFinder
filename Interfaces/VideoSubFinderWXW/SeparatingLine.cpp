                              //SeparatingLine.cpp//                                
//////////////////////////////////////////////////////////////////////////////////
//																				//
// Author:  Simeon Kosnitsky													//
//          skosnits@gmail.com													//
//																				//
// License:																		//
//     This software is released into the public domain.  You are free to use	//
//     it in any way you like, except that you may not sell this source code.	//
//																				//
//     This software is provided "as is" with no expressed or implied warranty.	//
//     I accept no liability for any damage or loss of business that this		//
//     software may cause.														//
//																				//
//////////////////////////////////////////////////////////////////////////////////

#include "SeparatingLine.h"
#include <algorithm>
#include <cmath>

BEGIN_EVENT_TABLE(CSeparatingLine, wxWindow)
	EVT_PAINT(CSeparatingLine::OnPaint)
	EVT_ERASE_BACKGROUND(CSeparatingLine::OnEraseBackground)
	EVT_LEFT_DOWN(CSeparatingLine::OnLButtonDown)
	EVT_LEFT_UP(CSeparatingLine::OnLButtonUp)
	EVT_MOTION(CSeparatingLine::OnMouseMove)
	EVT_MOUSE_CAPTURE_LOST(CSeparatingLine::OnMouseCaptureLost)
END_EVENT_TABLE()

CSeparatingLine::CSeparatingLine(wxWindow* parent, int w, int h, int sw, int sh, int minpos, int maxpos, int offset, int orientation, wxColour main_colour, wxColour border_colour, wxWindowID id)
		: wxWindow( parent, id, wxDefaultPosition, wxDefaultSize,
							wxTRANSPARENT_WINDOW | wxWANTS_CHARS
							)
{
	m_bDown = false;
	m_pParent = parent;
	m_main_colour = main_colour;
	m_border_colour = border_colour;

	m_w = w;
	m_h = h;

	m_sw = sw;
	m_sh = sh;

	m_min = minpos;
	m_max = maxpos;

	m_offset = offset;

	m_orientation = orientation;

	m_pos = 0;
	m_pos_min = 0;
	m_pos_max = 1;
	m_symmetric_drag_lower_side = true;
	m_symmetric_drag_center = 0.5;
	m_symmetric_drag_min_gap = 0.05;

	wxRect rc;

	if (m_orientation == 0)
	{
		this->SetCursor( wxCursor( wxCURSOR_SIZENS ) );

		rc.x = m_offset-m_sw;		
		rc.y = m_min-m_h/2-m_sh;
		rc.width = m_w+2*m_sw;
		rc.height = m_h+2*m_sh;
	}	
	else
	{
		this->SetCursor( wxCursor( wxCURSOR_SIZEWE ) );

		rc.x = m_min-m_w/2-m_sw;
		rc.y = m_offset-m_sh;
		rc.width = m_w+2*m_sw;		
		rc.height = m_h+2*m_sh;
	}

	CreateNewRgn();

	//this->Raise();
	
	UpdateSL();
}

CSeparatingLine::~CSeparatingLine()
{
}

void CSeparatingLine::CreateNewRgn()
{
	wxPoint ps[20];
	int i = 0;

	if (m_orientation == 0)
	{
		ps[i].x = 0;
		ps[i].y = 0;
		i++;

		ps[i].x = m_sw;
		ps[i].y = m_sh;
		i++;

		ps[i].x = m_w+m_sw;
		ps[i].y = m_sh;
		i++;

		ps[i].x = m_w+2*m_sw;
		ps[i].y = 0;
		i++;

		ps[i].x = m_w+m_sw+1;
		ps[i].y = m_sh+(m_h+1)/2+1;
		i++;

		ps[i].x = m_w+m_sw+1;
		ps[i].y = m_sh+(m_h+1)/2-1;
		i++;

		ps[i].x = m_w+2*m_sw;
		ps[i].y = m_sh+m_h+m_sh;
		i++;

		ps[i].x = m_w+m_sw;
		ps[i].y = m_sh+m_h;
		i++;

		ps[i].x = m_sw;
		ps[i].y = m_sh+m_h;
		i++;

		ps[i].x = 0;
		ps[i].y = m_sh+m_h+m_sh;
		i++;

		ps[i].x = m_sw-1;
		ps[i].y = m_sh+(m_h+1)/2-1;
		i++;

		ps[i].x = m_sw-1;
		ps[i].y = m_sh+(m_h+1)/2+1;
		i++;
	}
	else
	{
		ps[i].x = 0;
		ps[i].y = 0;
		i++;

		ps[i].x = m_sw+1+(m_w+1)/2;
		ps[i].y = m_sh-1;
		i++;

		ps[i].x = m_sw-1+(m_w+1)/2;
		ps[i].y = m_sh-1;
		i++;

		ps[i].x = m_w+2*m_sw;
		ps[i].y = 0;
		i++;

		ps[i].x = m_w+m_sw;
		ps[i].y = m_sh;
		i++;

		ps[i].x = m_w+m_sw;
		ps[i].y = m_sh+m_h;
		i++;

		ps[i].x = m_w+2*m_sw;
		ps[i].y = m_h+2*m_sh;
		i++;

		ps[i].x = m_sw-1+(m_w+1)/2;
		ps[i].y = m_h+m_sh+1;
		i++;

		ps[i].x = m_sw+1+(m_w+1)/2;
		ps[i].y = m_h+m_sh+1;
		i++;

		ps[i].x = 0;
		ps[i].y = m_h+2*m_sh;
		i++;

		ps[i].x = m_sw;
		ps[i].y = m_h+m_sh;
		i++;

		ps[i].x = m_sw;
		ps[i].y = m_sh;
		i++;
	}

	m_rgn = wxRegion( (size_t)i, ps, wxWINDING_RULE );

	//this->SetShape(m_rgn);

	m_old_w = m_w;
	m_old_h = m_h;
}

void CSeparatingLine::OnLButtonDown( wxMouseEvent& event )
{
	m_bDown = true;
	if (m_pOppositeLine)
	{
		m_symmetric_drag_lower_side = (m_pos <= m_pOppositeLine->m_pos);
		m_symmetric_drag_center = (m_pos + m_pOppositeLine->m_pos) / 2.0;
		m_symmetric_drag_min_gap = GetMinimumOppositeGap();
	}
	this->CaptureMouse();
}

void CSeparatingLine::OnLButtonUp( wxMouseEvent& event )
{
	if (m_bDown == true) 
	{
		m_bDown = false;
		this->ReleaseMouse();
		
		this->Refresh(true);
	}
}

void CSeparatingLine::OnMouseCaptureLost(wxMouseCaptureLostEvent& event)
{
	if (m_bDown == true) 
	{
		m_bDown = false;
	}
}

void CSeparatingLine::OnMouseMove( wxMouseEvent& event )
{
	if (m_bDown == true) 
	{
		wxPoint pt = this->GetPosition();
		wxSize border = this->GetWindowBorderSize();

		MoveSL(wxPoint(pt.x + border.GetWidth() + event.m_x,
			pt.y + border.GetHeight() + event.m_y), event.ShiftDown());
	}
}

double CSeparatingLine::GetMinimumOppositeGap()
{
	if (!m_pOppositeLine)
	{
		return 0.0;
	}

	double current_gap = std::abs(m_pOppositeLine->m_pos - m_pos);
	if (current_gap <= 0.0)
	{
		return 0.0;
	}

	double gap = 0.05;
	if (m_pos <= m_pOppositeLine->m_pos)
	{
		if (m_pos_max < m_pOppositeLine->m_pos)
		{
			gap = std::max(gap, m_pOppositeLine->m_pos - m_pos_max);
		}
		if (m_pOppositeLine->m_pos_min > m_pos)
		{
			gap = std::max(gap, m_pOppositeLine->m_pos_min - m_pos);
		}
	}
	else
	{
		if (m_pos_min > m_pOppositeLine->m_pos)
		{
			gap = std::max(gap, m_pos_min - m_pOppositeLine->m_pos);
		}
		if (m_pOppositeLine->m_pos_max < m_pos)
		{
			gap = std::max(gap, m_pos - m_pOppositeLine->m_pos_max);
		}
	}

	return std::min(gap, current_gap);
}

void CSeparatingLine::MoveSL(wxPoint pt, bool symmetric)
{
	int val;
	double new_pos;

	if (m_orientation == 0)
		val = pt.y;
	else 
		val = pt.x;

	if (val > m_max)
	{
		new_pos = 1;
	}
	else
	{
		if (val < m_min)
		{
			new_pos = 0;
		}
		else
		{
			new_pos = (double)(val-m_min)/(double)(m_max-m_min);
		}
	}

	if (new_pos < m_pos_min) new_pos = m_pos_min;
	if (new_pos > m_pos_max) new_pos = m_pos_max;

	if (symmetric && m_pOppositeLine)
	{
		double min_pos = std::max(m_pos_min, 2.0 * m_symmetric_drag_center - m_pOppositeLine->m_pos_max);
		double max_pos = std::min(m_pos_max, 2.0 * m_symmetric_drag_center - m_pOppositeLine->m_pos_min);
		double half_gap = m_symmetric_drag_min_gap / 2.0;

		if (m_symmetric_drag_lower_side)
		{
			max_pos = std::min(max_pos, m_symmetric_drag_center - half_gap);
		}
		else
		{
			min_pos = std::max(min_pos, m_symmetric_drag_center + half_gap);
		}

		if (min_pos > max_pos)
		{
			new_pos = m_pos;
		}
		else
		{
			new_pos = std::max(min_pos, std::min(max_pos, new_pos));
			m_pos = new_pos;
			m_pOppositeLine->m_pos = 2.0 * m_symmetric_drag_center - m_pos;
			if (m_pOppositeLine->m_pos < m_pOppositeLine->m_pos_min) m_pOppositeLine->m_pos = m_pOppositeLine->m_pos_min;
			if (m_pOppositeLine->m_pos > m_pOppositeLine->m_pos_max) m_pOppositeLine->m_pos = m_pOppositeLine->m_pos_max;
			m_pOppositeLine->UpdateSL();
		}
	}
	else
	{
		m_pos = new_pos;
	}

	UpdateSL();
}

double CSeparatingLine::CalculateCurPos()
{
	wxRect rc;
	int val;
	double res;

	rc = this->GetRect();

	if (m_orientation == 0)
	{
		val = rc.y+m_h/2+m_sh;
	}
	else
	{
		val = rc.x+m_w/2+m_sw;
	}

	res = (double)(val-m_min)/(double)(m_max-m_min);

	return res;
}

int CSeparatingLine::GetCurPos()
{
	wxRect rc;
	int res;

	rc = this->GetRect();

	if (m_orientation == 0)
	{
		res = rc.y+m_h/2+m_sh;
	}
	else
	{
		res = rc.x+m_w/2+m_sw;
	}

	return res;
}

void CSeparatingLine::UpdateSL()
{
	wxRect rc;
	int pos;

	pos = m_min+(int)(m_pos*(double)(m_max-m_min));

	if ( (m_w != m_old_w) || (m_h != m_old_h) )
	{
		CreateNewRgn();
	}

	if (m_orientation == 0)
	{
		rc.x = m_offset-m_sw;		
		rc.y = pos-m_h/2-m_sh;
		rc.width = m_w+2*m_sw;
		rc.height = m_h+2*m_sh;
	}	
	else
	{
		rc.x = pos-m_w/2-m_sw;
		rc.y = m_offset-m_sh;
		rc.width = m_w+2*m_sw;		
		rc.height = m_h+2*m_sh;
	}


#ifdef WIN32
	this->Show(false);
#endif

	this->SetSize(rc);

#ifdef WIN32
	this->Show(true);
	this->Raise();
#endif

	this->Refresh(true);
}

void CSeparatingLine::OnPaint(wxPaintEvent& WXUNUSED(event))
{
	wxPaintDC dc(this);
	int w, h;

	this->GetClientSize(&w, &h);

	wxBrush borderBrush(m_border_colour);
	wxBrush mainBrush(m_main_colour);

	dc.SetBackgroundMode(wxTRANSPARENT);
	dc.DestroyClippingRegion();
	dc.SetClippingRegion(m_rgn);

	dc.SetBrush(borderBrush);
	dc.DrawRectangle(0, 0, w, h);

	dc.SetBrush(mainBrush);
	if (m_orientation == 0)
	{
		dc.DrawRectangle(m_sw, m_sh, m_w, m_h);
	}
	else
	{
		dc.DrawRectangle(m_sw, m_sh, m_w, m_h);
	}
}

void CSeparatingLine::OnEraseBackground(wxEraseEvent &event)
{
	wxDC *pdc = event.GetDC();

	int w, h;

	this->GetClientSize(&w, &h);

	wxBrush borderBrush(m_border_colour);
	wxBrush mainBrush(m_main_colour);

	pdc->SetBackgroundMode(wxTRANSPARENT);
	pdc->DestroyClippingRegion();
	pdc->SetClippingRegion(m_rgn);

	pdc->SetBrush(borderBrush);
	pdc->DrawRectangle(0, 0, w, h);

	pdc->SetBrush(mainBrush);
	if (m_orientation == 0)
	{
		pdc->DrawRectangle(m_sw, m_sh, m_w, m_h);
	}
	else
	{
		pdc->DrawRectangle(m_sw, m_sh, m_w, m_h);
	}
}
