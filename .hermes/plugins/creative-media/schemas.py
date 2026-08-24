"""Tool schemas for the creative-media toolset.

The provider routing contract lives HERE, in the schema the model reads on
every turn, not only in profile prose: GPT Image 2 direct is the default for
images (including every likeness edit); Sogni only on an explicit ask, and
always for video/music.
"""

CREATE_MEDIA_SCHEMA = {
    "name": "create_media",
    "description": (
        "Create an image, video, or music track. Starts a durable background "
        "job; images normally finish within this call, video and music return "
        "a job_id to poll with media_status. All outputs are saved inside the "
        "June workspace and can be delivered by replying with the returned "
        "MEDIA: line(s)."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "prompt": {
                "type": "string",
                "description": "Full creative prompt describing what to make.",
            },
            "provider": {
                "type": "string",
                "enum": ["gpt-image", "sogni"],
                "description": (
                    "Routing rule: use 'gpt-image' (GPT Image 2, direct "
                    "OpenAI) for image requests by default and for every "
                    "likeness/identity edit. Use 'sogni' ONLY when the user "
                    "explicitly asks for Sogni, Spark, or a Sogni model — "
                    "and always for video or music, which are Sogni-only."
                ),
            },
            "kind": {
                "type": "string",
                "enum": ["image", "video", "music"],
                "description": "Defaults to image. gpt-image supports image only.",
            },
            "aspect_ratio": {
                "type": "string",
                "enum": ["square", "landscape", "portrait"],
                "description": "Defaults to square.",
            },
            "quality": {
                "type": "string",
                "enum": ["fast", "hq", "pro"],
                "description": "Sogni render quality. Defaults to fast.",
            },
            "model": {
                "type": "string",
                "description": (
                    "Exact live Sogni model id only. Never guess a model id. "
                    "For video, omit this unless the user gave an exact id; "
                    "the provider chooses its compatible default."
                ),
            },
            "no_filter": {
                "type": "boolean",
                "description": (
                    "Sogni only. Pass true only when the user explicitly asks "
                    "to disable Sogni's content filter."
                ),
            },
            "width": {"type": "integer", "description": "Sogni image width, 512-2048."},
            "height": {"type": "integer", "description": "Sogni image height, 512-2048."},
            "count": {"type": "integer", "description": "Sogni variant count, 1-4."},
            "duration_seconds": {
                "type": "integer",
                "description": "Video/music length, 3-30. Defaults to 5.",
            },
            "reference_images": {
                "type": "array",
                "items": {"type": "string"},
                "description": (
                    "Absolute paths of reference images inside the June "
                    "workspace only (e.g. approved character sheets)."
                ),
            },
            "idempotency_key": {
                "type": "string",
                "description": (
                    "Optional dedupe key: retries with the same key reuse the "
                    "same job instead of rendering again."
                ),
            },
        },
        "required": ["prompt", "provider"],
    },
}

MEDIA_STATUS_SCHEMA = {
    "name": "media_status",
    "description": (
        "Check a creative job by job_id, or list recent jobs when called "
        "without one. Detects and reports interrupted jobs honestly."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "job_id": {"type": "string", "description": "Job id from create_media."},
        },
        "required": [],
    },
}

MEDIA_CANCEL_SCHEMA = {
    "name": "media_cancel",
    "description": (
        "Cancel a running or queued creative job. Stops the local render "
        "client; a Sogni render already submitted upstream may still spend "
        "its tokens server-side, but its output is discarded."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "job_id": {"type": "string", "description": "Job id to cancel."},
        },
        "required": ["job_id"],
    },
}

MEDIA_RESULT_SCHEMA = {
    "name": "media_result",
    "description": (
        "Fetch the finished files for a completed job, e.g. to re-deliver "
        "media without rendering again."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "job_id": {"type": "string", "description": "Job id to fetch."},
        },
        "required": ["job_id"],
    },
}
