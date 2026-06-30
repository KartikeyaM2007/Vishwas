const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

const parseError = async (response, fallback) => {
  let errData = {};
  try { errData = await response.json(); } catch(e){}
  const detail = errData.detail || errData.error || fallback;
  if (typeof detail === 'string') return detail;
  return detail.message || JSON.stringify(detail);
};

export const fetchComplaints = async () => {
  try {
    const response = await fetch(`${API_BASE_URL}/complaints`);
    if (!response.ok) {
      let errData = {};
      try { errData = await response.json(); } catch(e){}
      throw new Error(errData.detail || errData.error || 'Failed to fetch complaints');
    }
    return await response.json();
  } catch (error) {
    console.error("Error fetching complaints:", error);
    throw error;
  }
};

export const fetchReviewQueue = async () => {
  const response = await fetch(`${API_BASE_URL}/admin/review-queue`);
  if (!response.ok) {
    throw new Error(await parseError(response, 'Failed to fetch review queue'));
  }
  return response.json();
};

export const fetchComplaint = async (id) => {
  const response = await fetch(`${API_BASE_URL}/complaints/${id}`);
  if (!response.ok) {
    throw new Error(await parseError(response, 'Failed to fetch complaint'));
  }
  return response.json();
};

export const fetchComplaintAudit = async (id) => {
  const response = await fetch(`${API_BASE_URL}/complaints/${id}/audit`);
  if (!response.ok) return { data: [] };
  return response.json();
};

const adminPatch = async (id, path, payload) => {
  const response = await fetch(`${API_BASE_URL}/admin/complaints/${id}/${path}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(await parseError(response, `Failed to ${path} complaint`));
  }
  return response.json();
};

export const approveComplaint = (id, payload = {}) => adminPatch(id, 'approve', { admin_id: 'admin', ...payload });
export const rejectComplaint = (id, payload = {}) => adminPatch(id, 'reject', { admin_id: 'admin', ...payload });
export const requestMoreProof = (id, payload = {}) => adminPatch(id, 'request-more-proof', { admin_id: 'admin', ...payload });
export const assignComplaint = (id, payload = {}) => adminPatch(id, 'assign', { admin_id: 'admin', ...payload });
export const updateAdminStatus = (id, payload = {}) => adminPatch(id, 'status', { admin_id: 'admin', ...payload });

export const fetchComments = async (complaintId, sort = 'newest') => {
  const response = await fetch(`${API_BASE_URL}/complaints/${complaintId}/comments?sort=${encodeURIComponent(sort)}`);
  if (!response.ok) {
    throw new Error(await parseError(response, 'Failed to fetch comments'));
  }
  return response.json();
};

export const addComment = async (complaintId, payload) => {
  const response = await fetch(`${API_BASE_URL}/complaints/${complaintId}/comments`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(await parseError(response, 'Failed to add comment'));
  }
  return response.json();
};

export const replyToComment = async (complaintId, commentId, payload) => {
  const response = await fetch(`${API_BASE_URL}/complaints/${complaintId}/comments/${commentId}/reply`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(await parseError(response, 'Failed to add reply'));
  }
  return response.json();
};

export const editComment = async (commentId, payload) => {
  const response = await fetch(`${API_BASE_URL}/comments/${commentId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(await parseError(response, 'Failed to edit comment'));
  }
  return response.json();
};

export const deleteComment = async (commentId) => {
  const response = await fetch(`${API_BASE_URL}/comments/${commentId}`, { method: 'DELETE' });
  if (!response.ok) {
    throw new Error(await parseError(response, 'Failed to delete comment'));
  }
  return response.json();
};

export const voteComment = async (commentId, direction) => {
  const response = await fetch(`${API_BASE_URL}/comments/${commentId}/${direction}`, { method: 'POST' });
  if (!response.ok) {
    throw new Error(await parseError(response, 'Failed to vote on comment'));
  }
  return response.json();
};

export const analyzeQuery = async (query) => {
  try {
    const response = await fetch(`${API_BASE_URL}/gemini-analyze`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query })
    });
    
    if (!response.ok) {
      let errData = {};
      try { errData = await response.json(); } catch(e){}
      throw new Error(errData.detail || errData.error || 'Failed to analyze query');
    }
    return await response.json();
  } catch (error) {
    console.error("Error analyzing query:", error);
    throw error;
  }
};

export const confirmComplaint = async (id) => {
  const response = await fetch(`${API_BASE_URL}/complaints/${id}/confirm`, { method: 'POST' });
  if (!response.ok) {
    let errData = {};
    try { errData = await response.json(); } catch(e){}
    throw new Error(errData.detail || errData.error || 'Failed to confirm complaint');
  }
  return response.json();
};

export const markDuplicate = async (id) => {
  const response = await fetch(`${API_BASE_URL}/complaints/${id}/duplicate`, { method: 'POST' });
  if (!response.ok) {
    let errData = {};
    try { errData = await response.json(); } catch(e){}
    throw new Error(errData.detail || errData.error || 'Failed to mark duplicate');
  }
  return response.json();
};

export const updateComplaintStatus = async (id, status, resolvedImageFile) => {
  const formData = new FormData();
  formData.append('complaint_id', id);
  formData.append('status', status);
  if (resolvedImageFile) formData.append('resolved_image', resolvedImageFile);

  const response = await fetch(`${API_BASE_URL}/update-complaint`, {
    method: 'PUT',
    body: formData,
  });
  if (!response.ok) {
    let errData = {};
    try { errData = await response.json(); } catch(e){}
    throw new Error(errData.detail || errData.error || 'Failed to update status');
  }
  return response.json();
};


